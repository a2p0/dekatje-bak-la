# Contract — `TutorSimulation::StructuralMetrics` (API interne)

**Branche** : `039-structural-metrics`
**Type** : interface interne Ruby (pas d'endpoint HTTP, pas de CLI public).
**Consumers** : `TutorSimulation::Runner`, `TutorSimulation::ReportGenerator`.

## Public methods

### `StructuralMetrics.compute(conversation:, phase_per_turn: nil)`

**Purpose** : calculer l'ensemble des métriques déterministes d'une conversation simulée.

**Parameters**

| Nom | Type | Requis | Défaut | Description |
|---|---|---|---|---|
| `conversation:` | `Conversation` (AR model, persisté) | ✅ | — | Conversation avec `tutor_state` chargé et `messages` accessibles |
| `phase_per_turn:` | `Array[String]` \| `nil` | ❌ | `nil` | Historique des phases capturé par le Runner. Si `nil`, les métriques qui en dépendent retournent `nil` (rétrocompat) |

**Returns** : `Hash{Symbol => Object}` (cf. `data-model.md` § 1)

**Raises** : jamais d'exception sur données valides (messages vides, phase_per_turn vide ou mal formé).
Si `conversation` est `nil`, laisse remonter `NoMethodError` — c'est un bug du caller, pas un cas métier.

**Contract tests** (cf. `spec/services/tutor_simulation/structural_metrics_spec.rb`)

| Test | Input | Expected output |
|---|---|---|
| C1 (existant) | conversation à 2 messages assistant (dont 1 neutral relaunch) | hash avec 6 clés existantes intactes |
| C2 (nouveau) | `phase_per_turn: nil` | `first_turn_with_transition == nil` ET `action_verb_ratio_guiding == nil` |
| C3 (nouveau) | `phase_per_turn: ["idle", "greeting", ...]` | `first_turn_with_transition == 1` |
| C4 (nouveau) | `phase_per_turn: ["idle", "idle", "greeting"]` | `first_turn_with_transition == 2` |
| C5 (nouveau) | `phase_per_turn: ["idle", "idle", "idle"]` | `first_turn_with_transition == nil` |
| C6 (nouveau) | `phase_per_turn: ["guiding", "guiding"]` + 3 msgs guiding dont 2 commencent par "Identifie" / "Calcule" | `action_verb_ratio_guiding ≈ 0.67` |
| C7 (nouveau) | phase_per_turn n'atteint jamais guiding | `action_verb_ratio_guiding == nil` |
| C8 (nouveau) | messages guiding : "  identifie..." (lowercase) | compté comme action verb |
| C9 (nouveau) | 2 messages en phase guiding mentionnant "DT1" | `dt_dr_leak_count_non_spotting == 2` |
| C10 (nouveau) | message en phase spotting mentionnant "DT1" | non compté (leak only hors spotting) |
| C11 (nouveau) | 4 messages assistant sur 5 font ≤ 60 mots | `short_message_ratio == 0.80` |
| C12 (nouveau) | 0 messages assistant | `short_message_ratio == 0.0` ET nouvelles métriques stables |

---

## `TutorSimulation::Runner` — nouveau comportement `SKIP_JUDGE`

**Purpose** : permettre la désactivation du juge LLM via env var.

**Input** : `ENV["SKIP_JUDGE"]` lu dans `Runner#simulate_profile`.
**Output affecté** : clé `:evaluation` du hash par profil.

### Règle

```ruby
evaluation = if ENV["SKIP_JUDGE"] == "1"
  { "skipped" => true }
else
  judge_transcript(question, profile, simulator.profile_label, transcript)
end
```

### Contract tests (cf. `spec/services/tutor_simulation/runner_spec.rb`)

| Test | Setup | Expected |
|---|---|---|
| R1 (nouveau) | `ENV["SKIP_JUDGE"] = "1"` | `fake_judge.evaluate` jamais appelé |
| R2 (nouveau) | `ENV["SKIP_JUDGE"] = "1"` | chaque profil result : `evaluation == { "skipped" => true }` |
| R3 (nouveau) | `ENV["SKIP_JUDGE"]` absent | `fake_judge.evaluate` appelé normalement (rétrocompat) |
| R4 (nouveau) | `ENV["SKIP_JUDGE"] = "0"` | traité comme absent (strict `== "1"`) |

---

## `TutorSimulation::ReportGenerator` — rendu étendu

**Purpose** : afficher les 4 nouvelles métriques dans le rapport markdown + gérer le cas juge désactivé.

### Zones touchées

#### 1. `#render_structural(lines, metrics)` — lignes de tableau par profil

Ajouter après les lignes existantes :

```markdown
| 1er tour avec transition (H1) | {first_turn_with_transition ou "—"} |
| % verbes d'action en guiding (H2) | {action_verb_ratio_guiding ou "—"} |
| Leaks DT/DR hors spotting | {dt_dr_leak_count_non_spotting} |
| % messages ≤ 60 mots (cible ≥0.7) | {short_message_ratio} |
```

#### 2. `#render_qualitative(lines, evaluation)` — nouveau branch

Avant le branch "error", insérer :

```ruby
if evaluation&.dig("skipped")
  lines << "> ⊙ Juge désactivé (SKIP_JUDGE=1) — évaluation qualitative non disponible."
  lines << ""
  return
end
```

#### 3. `#global_summary` — moyennes/sommes des 4 nouvelles métriques

Ajouter dans le bloc "Structurel" :

```markdown
| 1er tour transition moyen (H1) | {moyenne des non-nil ou "—"} |
| % verbes d'action moyen (H2) | {moyenne des non-nil ou "—"} |
| Leaks DT/DR totaux | {somme} |
| % messages courts moyen | {moyenne} |
```

### Contract tests (cf. `spec/services/tutor_simulation/report_generator_spec.rb`)

| Test | Input | Expected output |
|---|---|---|
| G1 (nouveau) | metrics avec les 4 nouveaux champs | markdown contient les 4 lignes correspondantes |
| G2 (nouveau) | `evaluation == { "skipped" => true }` | markdown contient "Juge désactivé" et PAS de tableau de scores |
| G3 (nouveau) | mix de metrics avec `first_turn_with_transition` partiellement nil | résumé global affiche la moyenne des non-nil |

---

## Signatures non changées (rétrocompat)

- `StructuralMetrics.compute(conversation:)` — **continue à fonctionner** (kwarg nouveau a un défaut `nil`). Tous les specs existants passent sans modification.
- `ReportGenerator.new(simulation_data)` — signature identique.
- `ReportGenerator#to_json`, `#to_markdown` — signatures identiques.
- `Runner#run`, `Runner.new(...)` — signatures identiques.
