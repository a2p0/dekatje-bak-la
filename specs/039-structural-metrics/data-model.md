# Data Model — Metrics structurelles déterministes

**Branche** : `039-structural-metrics`
**Date** : 2026-04-16

Ce feature n'introduit **aucune entité persistée** : pas de nouvelle table, pas
de migration, pas de colonne ajoutée. Les "entités" ici sont des structures de
données in-memory qui voyagent entre `Runner`, `StructuralMetrics`,
`ReportGenerator` et le JSON sérialisé `raw.json`.

## Entités in-memory

### 1. `StructuralMetricsResult` (hash retourné par `StructuralMetrics.compute`)

Hash symbol-keyed, composition :

| Clé | Type | Nouveauté | Source | Sentinelle |
|---|---|---|---|---|
| `final_phase` | String | existante | `tutor_state.current_phase` | `"idle"` |
| `phase_rank` | Integer (0..7) | existante | `PHASE_RANK[final_phase]` | `0` |
| `avg_message_length_words` | Numeric | existante | moyenne sur messages assistant | `0` |
| `open_question_ratio` | Float (0.0..1.0) | existante | ratio messages `?` sur total | `0.0` |
| `regex_intercepts` | Integer | existante | count messages == `NEUTRAL_RELAUNCH` | `0` |
| `hints_used` | Integer | existante | somme des `hints_used` par question | `0` |
| `message_count_assistant` | Integer | existante | count messages role=assistant | `0` |
| `message_count_user` | Integer | existante | count messages role=user | `0` |
| **`first_turn_with_transition`** | Integer \| nil | **nouvelle** | index 1-based du 1er changement de phase dans `phase_per_turn` | `nil` |
| **`action_verb_ratio_guiding`** | Float \| nil | **nouvelle** | ratio messages guiding dont 1er mot ∈ `ACTION_VERBS` | `nil` |
| **`dt_dr_leak_count_non_spotting`** | Integer | **nouvelle** | si `phase_per_turn` fourni : count messages hors spotting matchant `/DT\d+\|DR\d+/`. Sinon : count de TOUS les messages matchant (mode diagnostic rétrocompat) | `0` |
| **`short_message_ratio`** | Float | **nouvelle** | ratio messages ≤ 60 mots sur total assistant | `0.0` (sentinelle spéciale : aucun message) |
| **`phase_per_turn`** | Array[String] \| nil | **nouvelle** (trace) | snapshot tel que passé en kwarg | `nil` |

#### Invariants

- **Invariant I1** : si `phase_per_turn == nil`, alors
  `first_turn_with_transition == nil` ET `action_verb_ratio_guiding == nil`.
  (Les deux métriques dépendantes de l'historique retournent `nil` en l'absence de données.)
- **Invariant I2** : si `phase_per_turn.any?` mais qu'aucun élément n'est différent
  de `"idle"`, alors `first_turn_with_transition == nil`.
- **Invariant I3** : `action_verb_ratio_guiding ∈ [0.0, 1.0]` quand non-nil.
- **Invariant I4** : `short_message_ratio ∈ [0.0, 1.0]`.
- **Invariant I5** : si `message_count_assistant == 0`, alors
  `short_message_ratio == 0.0` (par convention — pas de division par zéro).
- **Invariant I6** : `dt_dr_leak_count_non_spotting >= 0` toujours.
- **Invariant I6bis** : quand `phase_per_turn == nil`, `dt_dr_leak_count_non_spotting` compte tous les messages assistant matchant `DT_DR_REGEX` (pas de filtrage par phase possible). Quand `phase_per_turn` fourni, filtrage strict hors `"spotting"`.

### 2. `phase_per_turn` (Array\[String\], capturé par Runner)

Tableau 1-indexé par tour (en pratique : Array Ruby 0-indexé mais interprété
comme "tour 1 = index 0" par les métriques).

Exemple :
```ruby
["idle", "greeting", "reading", "spotting", "guiding", "guiding", "validating"]
# signifie : avant le 1er message assistant, phase=idle ;
#            après le 1er message, phase=greeting ; etc.
```

#### Règle de capture et convention d'alignement

Dans `Runner#simulate_profile`, AVANT la boucle :

```ruby
phase_per_turn = [conversation.tutor_state.current_phase]  # phase avant tout message
```

APRÈS chaque `Tutor::ProcessMessage.call` :

```ruby
conversation.reload
phase_per_turn << conversation.tutor_state.current_phase
```

**Convention d'alignement (IMPORTANT pour US1 et US2)** :

- `phase_per_turn[0]` = phase AVANT le 1er message assistant (typiquement `"idle"`).
- `phase_per_turn[i]` pour `i >= 1` = phase APRÈS le i-ème tour assistant (1-indexé).
- Une conversation de N tours assistants produit donc un tableau de **N+1** éléments.

**Conséquences pour le calcul des metrics** :

- `first_turn_with_transition` : on cherche le premier indice `i >= 1` tel que
  `phase_per_turn[i] != phase_per_turn[i-1]` ET `phase_per_turn[i] != "idle"`.
  La valeur retournée est `i` (1-indexé, correspond au numéro de tour où la
  transition s'est produite).

- `action_verb_ratio_guiding` : le i-ème message assistant (1-indexé) est
  considéré "émis EN phase guiding" si `phase_per_turn[i] == "guiding"`
  (c'est-à-dire que la phase APRÈS ce tour est guiding, ce qui signifie que
  pendant la rédaction du message, le tuteur était en guiding ou venait d'y
  transitionner). Justification : `Tutor::ApplyToolCalls` applique la
  transition AVANT la génération du texte, donc la phase observée *après*
  le tour reflète le contexte de rédaction du message.

- `dt_dr_leak_count_non_spotting` : idem, la phase de référence est
  `phase_per_turn[i]` pour le i-ème message assistant.

**Edge case** : si `phase_per_turn` est fourni mais `phase_per_turn.size < message_count_assistant + 1`, l'alignement est cassé (bug du caller). Le service doit dégrader en tolérant : les messages assistants au-delà de `phase_per_turn.size - 1` sont ignorés des metrics dépendantes de la phase. Logger un warning via `Rails.logger.warn`.

#### Calcul de `first_turn_with_transition`

```ruby
# phase_per_turn = ["idle", "greeting", "reading", ...]
# On cherche le premier index > 0 où la phase ≠ "idle" ET ≠ phase_per_turn[index-1]
first_non_idle_index = phase_per_turn.each_with_index.find do |phase, i|
  i > 0 && phase != "idle" && phase != phase_per_turn[i-1]
end
# first_turn_with_transition = first_non_idle_index ? first_non_idle_index[1] : nil
# (retourne l'index, qui correspond au tour 1-indexé car index 0 = phase avant tour 1)
```

### 3. `ProfileResult[:evaluation]` — marker `skipped`

Hash retourné par `Runner#simulate_profile` dans la clé `:evaluation`. Trois
formes possibles :

| Forme | Déclencheur | Exemple |
|---|---|---|
| Hash de scores juge | cas normal | `{ "non_divulgation" => { "score" => 4, "justification" => "..." }, "synthese" => "..." }` |
| `{ "error" => String }` | exception pendant appel juge | `{ "error" => "Net::ReadTimeout" }` |
| **`{ "skipped" => true }`** | **nouvelle** — `ENV["SKIP_JUDGE"] == "1"` | `{ "skipped" => true }` |

#### Règle de discrimination

`ReportGenerator#render_qualitative` applique dans l'ordre :
1. Si `evaluation.key?("error")` → bloc d'erreur (existant).
2. **Sinon si `evaluation["skipped"] == true` → bloc "Juge désactivé" (nouveau).**
3. Sinon → bloc tableau de scores (existant).

### 4. Constantes de classe (StructuralMetrics)

```ruby
ACTION_VERBS = %w[identifie repère cite relève compare calcule].freeze
DT_DR_REGEX  = /\b(?:DT|DR)\d+\b/i.freeze
SHORT_MESSAGE_WORD_THRESHOLD = 60
```

| Constante | Origine | Drift risk |
|---|---|---|
| `ACTION_VERBS` | Liste figée issue du prompt H2 (commit `3a2895f`) | Si prompt H2 change → mettre à jour ici en parallèle. Un spec du prompt pourrait comparer les deux listes (hors scope) |
| `DT_DR_REGEX` | Convention BAC : documents techniques DT1, DT2, réponses DR1, DR2… | Très stable |
| `SHORT_MESSAGE_WORD_THRESHOLD` | Règle "Maximum 60 mots" du prompt `Tutor::BuildContext` (ligne 11) | Si règle change → mettre à jour ici |

## Relations et flux

```text
Runner#simulate_profile
    │
    ├─ initialise  phase_per_turn = [conversation.tutor_state.current_phase]
    │
    ├─ boucle 1..max_turns :
    │     ├─ StudentSimulator.respond(...)
    │     ├─ Tutor::ProcessMessage.call(...)
    │     └─ phase_per_turn << conversation.reload.tutor_state.current_phase
    │
    ├─ structural = StructuralMetrics.compute(
    │                  conversation:   conversation,
    │                  phase_per_turn: phase_per_turn
    │                )
    │
    ├─ evaluation = ENV["SKIP_JUDGE"] == "1" ? { "skipped" => true } : judge_transcript(...)
    │
    └─ retourne { profile:, structural_metrics: structural, evaluation:, ... }
          │
          ▼
    build_simulation_data → raw.json (sérialisation directe du hash)
                          ↓
    ReportGenerator → report.md
          ├─ render_structural (4 nouvelles lignes de tableau)
          ├─ render_qualitative (1 nouveau branch "skipped")
          └─ global_summary (moyennes des 4 nouvelles métriques)
```

## Validation

Pas de validation ActiveRecord (aucune entité DB). La validation se fait via les
tests RSpec des invariants I1-I6 ci-dessus.
