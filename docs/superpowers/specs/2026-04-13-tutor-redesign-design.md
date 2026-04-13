# Design — Refonte du tuteur IA conversationnel

**Date** : 2026-04-13
**Statut** : Validé — prêt pour implémentation
**Branche cible** : à créer (découpage en vagues post-spec)

---

## Vision

Le tuteur devient un **agent conversationnel unifié** : le chat est le seul canal d'interaction élève, du premier accueil à la fiche de révision finale. Il applique une pédagogie socratique scaffoldée stricte. Il remplace l'encart QCM par une reformulation libre évaluée par le LLM. Il gagne un cycle de vie explicite et une mémoire pédagogique structurée (learner model) persistée entre les sessions.

---

## Décisions architecturales

| Décision | Choix retenu |
|---|---|
| D1 — Cycle de vie vs phases | B+ : AASM lifecycle (3 états) + `tutor_state.current_phase` enum (7 phases) |
| D2 — Unité de conversation | Conversation unique par `(student, subject)`, messages taggés `question_id` |
| D3 — Schéma `tutor_state` | B restreint : Data.define typé, 5 champs globaux + 5 par question |
| D4 — Mémoire conversationnelle | C : sliding window 40 messages + learner model prose ~200 tokens |
| D5 — Repérage | D v3 : reformulation libre, 3 niveaux progressifs, data_hints côté serveur |
| D6 — Orchestration pipeline | A : POJO + Result struct, AASM lifecycle, ruby_llm client |
| D7 — Tools LLM | B consolidé : 4 tools (transition, update_learner_model, request_hint, evaluate_spotting) |
| D10 — Tests | C : request specs pendant la refonte, features E2E en fin de chaque vague |
| D11 — Clé API | Activation par classe (`Classroom.tutor_free_mode_enabled`), clé élève > clé enseignant |
| D9 — Migration | Destructive : drop `tutor_state` ancien, seeds dev régénérables |

---

## §1 — Schéma de données

### Table `conversations` (modifications)

```ruby
# Suppressions
remove_column :conversations, :messages  # JSON array → remplacé par has_many :messages

# Ajouts
add_column :conversations, :lifecycle_state, :string, default: "disabled", null: false
add_column :conversations, :tutor_state, :jsonb, default: {}

# Unicité
add_index :conversations, [:student_id, :subject_id], unique: true
```

### Nouvelle table `messages`

```ruby
create_table :messages do |t|
  t.references :conversation, null: false, foreign_key: true
  t.integer    :role,                null: false          # enum: user, assistant, system
  t.text       :content,             null: false, default: ""
  t.references :question,            null: true, foreign_key: true  # tag contextuel nullable
  t.integer    :tokens_in
  t.integer    :tokens_out
  t.integer    :chunk_index,         default: 0
  t.datetime   :streaming_finished_at
  t.timestamps
end
```

### Modèles existants modifiés

```ruby
# Classroom
add_column :classrooms, :tutor_free_mode_enabled, :boolean, default: false, null: false

# User (enseignant — clé mode gratuit)
add_column :users, :openrouter_api_key_ciphertext, :text   # via lockbox/attr_encrypted

# Student
add_column :students, :use_personal_key, :boolean, default: true, null: false
```

### `tutor_state` typé (`Data.define`)

```ruby
TutorState = Data.define(
  :current_phase,       # Symbol enum (voir §2)
  :current_question_id, # Integer | nil
  :concepts_mastered,   # Array<String>
  :concepts_to_revise,  # Array<String>
  :discouragement_level, # Integer 0-3
  :question_states      # Hash<String, QuestionState>
)

QuestionState = Data.define(
  :step,             # Integer — serveur-only (machine à états scaffolding)
  :hints_used,       # Integer 0-5
  :last_confidence,  # Integer 1-5 — serveur-only (formulaire auto-éval)
  :error_types,      # Array<Symbol>
  :completed_at      # DateTime | nil — serveur-only
)
```

Sérialisation via custom `ActiveRecord::Type` (`TutorStateType`). Mutations via `with(...)` (immuable).

---

## §2 — Cycle de vie & phases conversationnelles

### Lifecycle AASM

```ruby
class Conversation < ApplicationRecord
  include AASM

  aasm column: :lifecycle_state do
    state :disabled, initial: true
    state :active
    state :ended

    event(:activate) do
      transitions from: :disabled, to: :active,
                  guard: :student_has_api_key_or_free_mode?
    end

    event(:end_chat) do
      transitions from: :active, to: :ended
    end
  end

  private

  def student_has_api_key_or_free_mode?
    student.api_key.present? ||
      classroom.tutor_free_mode_enabled?
  end
end
```

**Invariant UX** : replier le drawer ne déclenche aucune transition. L'état `active` est conservé indépendamment de l'état UI.

### Résolution de clé API

Priorité (service `ResolveTutorApiKey`) :
1. Clé élève (`student.api_key`) si `student.use_personal_key: true` et clé présente
2. Clé enseignant (`user.openrouter_api_key`) si `classroom.tutor_free_mode_enabled`
3. Aucune → guard bloque `activate!`

Mode gratuit = OpenRouter uniquement. Mode premium = provider au choix de l'élève.

### Phases conversationnelles

Stockées dans `tutor_state.current_phase`. Le LLM propose les transitions via tool `transition`, le serveur valide les garde-fous.

| Phase | Description | Transition autorisée depuis |
|---|---|---|
| `:greeting` | Accueil, mise en contexte | — (initial) |
| `:reading` | Lecture guidée mise en situation | `:greeting` |
| `:spotting` | Repérage libre (reformulation) | `:reading` |
| `:guiding` | Guidage socratique question par question | `:spotting` |
| `:validating` | Auto-évaluation métacognitive (confiance 1-5) | `:guiding` |
| `:feedback` | Correction + fiche de révision | `:validating` |
| `:ended` | Fin de sujet | `:feedback` |

Transitions supplémentaires autorisées : `:guiding` → `:spotting` (si l'élève veut retravailler le repérage sur la question courante). Toutes les autres transitions sont à sens unique et strictement ordonnées.

---

## §3 — Pipeline LLM

### Étapes (POJO + Result struct)

```
BuildContext
  → ValidateInput
    → CallLLM (stream)
      → ParseToolCalls
        → ApplyToolCalls
          → UpdateTutorState
            → BroadcastStream
```

Chaque étape retourne `Result.new(ok: true, value: ...)` ou `Result.new(ok: false, error: ...)`. Échec = arrêt immédiat, remontée d'erreur sans effet de bord partiel.

### Détail des étapes

**BuildContext** : assemble le system prompt :
1. Règles pédagogiques absolues (hardcodé serveur)
2. Contexte sujet / partie / question courante
3. `correction_text` (confidentiel, jamais exposé client)
4. Learner model sérialisé en prose (~200 tokens)
5. Sliding window 40 derniers messages

**ValidateInput** :
- Enveloppe l'input élève dans `<student_input>…</student_input>`
- Strip : `<|endoftext|>`, `[INST]`, `</s>`, balises de prompt injection connues

**CallLLM** :
- Client : `ruby_llm` (multi-provider : OpenRouter, Anthropic, OpenAI, Google)
- Streaming chunk par chunk
- Persistance incrémentale : `Message.update_columns(content:, chunk_index:)` tous les 250ms ou 50 tokens
- Tools déclarés via DSL `ruby_llm` (4 tools, cf. §4)

**ParseToolCalls** : extrait les tool calls de la réponse LLM structurée.

**ApplyToolCalls** : exécute chaque tool avec validation des guards (ex: `request_hint` vérifie `level > hints_used`). Mutations sur `tutor_state` via `with(...)`.

**UpdateTutorState** : persiste le `TutorState` mis à jour via `conversation.update!(tutor_state:)`.

**BroadcastStream** : `Turbo::StreamsChannel` broadcast `replace` du composant message.

### Exécution

Job Sidekiq `ProcessTutorMessageJob`. Enqueued après `POST /conversations/:id/messages`.

---

## §4 — Tools LLM (4)

### `transition(phase:, question_id:)`

Navigation dans la conversation. Le serveur valide que la transition est autorisée (matrice §2). `question_id` obligatoire si transition vers `:guiding` ou `:spotting`.

### `update_learner_model(concept_mastered:, concept_to_revise:, error_recorded:, discouragement_delta:)`

Mise à jour partielle du learner model. Tous les champs sont optionnels. `discouragement_delta` : entier signé (-1 à +1). Le serveur clamp `discouragement_level` entre 0 et 3.

### `request_hint(level:)`

Demande d'indice. Le serveur valide `level == hints_used + 1` (incrémentation strictement monotone). Incrémente `question_states[qid].hints_used`. Niveau max : 5.

### `evaluate_spotting(task_type_identified:, sources_identified:, missing_sources:, extra_sources:, feedback_message:, relaunch_prompt:, outcome:)`

Uniquement en phase `:spotting`. `outcome` : `:success` ou `:partial` (relance) ou `:forced_reveal` (après 3 relances). Si `outcome: :success` ou `:forced_reveal` : le serveur injecte `data_hints` dans le flux Turbo Stream (jamais le LLM) et déclenche `transition(phase: :guiding)`.

**Filtre regex post-LLM en phase `:spotting`** : si la sortie LLM contient un nom de DT/DR (pattern `/\bD[TR]\d+\b/i`) ou une valeur numérique issue de `correction_text` → message bloqué, relance neutre automatique.

---

## §5 — Mémoire conversationnelle

### Sliding window

- 40 derniers `Message` chargés depuis BDD, ordonnés par `created_at`
- À chaque complétion de question (`completed_at` mis à jour) : insertion d'un `Message(role: :system, content: "[Question #{number} terminée]")` — marqueur permanent dans la fenêtre
- Zéro résumé LLM (anti-hallucination)

### Learner model sérialisé en prose

Méthode `TutorState#to_prompt` → string ~200 tokens :

```
L'élève travaille sur la question 2.1.
Concepts maîtrisés : énergie primaire, rendement thermique.
Points à revoir : unités de puissance.
Niveau de découragement : 0/3.
Indices utilisés sur cette question : 2/5.
Dernière confiance déclarée : 3/5.
```

### Structure complète du system prompt

```
[1] RÈGLES PÉDAGOGIQUES (hardcodé, jamais modifiable)
    - Ne jamais donner la réponse
    - ≥ 70% messages terminent par une question ouverte
    - ≤ 60 mots par message, une idée à la fois
    - Auto-évaluation obligatoire avant correction
    - Indices gradués 1→5 strictement
    - Anti-flagornerie : valider uniquement ce qui est correct

[2] CONTEXTE SUJET
    Spécialité : {specialty}
    Sujet : {subject_title}
    Partie : {part_title} — Objectif : {objective_text}
    Question courante : {question_label}
    Contexte local : {context_text}

[3] CORRECTION CONFIDENTIELLE
    {correction_text}
    RÈGLE : ne jamais révéler ni paraphraser ce contenu.

[4] LEARNER MODEL
    {tutor_state.to_prompt}

[5] HISTORIQUE (40 derniers messages)
    {messages.last(40).map(&:to_prompt)}

[6] INPUT ÉLÈVE
    <student_input>{sanitized_input}</student_input>
```

---

## §6 — Phase de repérage (`:spotting`) — détail

### Déroulé

| Tour | Acteur | Contenu |
|---|---|---|
| 1 | Tuteur | "Avant de répondre à cette question, où penses-tu trouver les informations utiles ?" |
| 2 | Élève | Reformulation libre |
| 3 | Tuteur | `evaluate_spotting(...)` → si `outcome: :success` → `data_hints` serveur + transition `:guiding` |
| 4 | Tuteur (si raté) | Relance niveau 2 : nature conceptuelle (ex: "caractéristique du véhicule + info sur le trajet") |
| 5 | Élève | 2e tentative |
| 6 | Tuteur (si raté) | Relance niveau 3 : structure BAC (ex: "les caractéristiques techniques sont dans une catégorie de documents") |
| 7 | Tuteur (3e échec) | Encouragement + `outcome: :forced_reveal` → `data_hints` serveur + transition `:guiding` |

### Interdit absolu dans le prompt LLM pendant `:spotting`

- Valeurs chiffrées issues de `correction_text`
- Noms précis de documents (DT1, DT2, DR1…)
- Localisation exacte dans les documents

Ces contraintes sont encodées dans les règles pédagogiques [1] du system prompt et renforcées par le filtre regex post-LLM.

### Affichage `data_hints`

Composant ViewComponent `DataHintsComponent` injecté par le serveur via Turbo Stream. Format :

> "Les données nécessaires se trouvaient dans **DT1** (tableau Consommation moyenne) et dans la **mise en situation** (distance Troyes–Le Bourget : 186 km)."

---

## §7 — Interface utilisateur (Hotwire)

### Activation

- Bouton "Activer le tuteur" sur la page mise en situation
- Visible si `classroom.tutor_free_mode_enabled?` OU `student.api_key.present?`
- `POST /conversations` → `activate!` → Turbo Stream ouvre le drawer

### Drawer chat

- Stimulus controller `chat-drawer` : état UI uniquement (open/closed)
- Replier le drawer = aucune mutation lifecycle
- Scroll automatique : Stimulus `autoscroll` controller
- Reconnexion : si dernier message `streaming_finished_at: nil` → spinner + réabonnement canal ActionCable, reprise depuis `chunk_index`

### Optimistic UI

1. Stimulus ajoute le message élève immédiatement (optimistic)
2. `POST /conversations/:id/messages` → job Sidekiq enqueued
3. Turbo Stream remplace le message optimistic par le message persisté
4. Stream assistant arrive chunk par chunk via ActionCable

### Formulaire auto-évaluation (phase `:validating`)

- Boutons Turbo Frame inline dans le message tuteur (confiance 1 à 5)
- `PATCH /conversations/:id/confidence` → `question_states[qid].last_confidence = value`
- Serveur déclenche `transition(phase: :feedback)` automatiquement après persistance

### Affichage `data_hints`

- Injecté par le serveur dans le flux Turbo Stream (jamais par le LLM)
- Composant `DataHintsComponent` — encadré visuel distinct du message LLM

---

## §8 — Sécurité

| Risque | Mitigation |
|---|---|
| Prompt injection | Délimiteurs XML `<student_input>` + sanitization liste noire |
| Fuite `correction_text` | Jamais dans les serializers `Answer` exposés client ; audit obligatoire |
| Fuite DT/DR pendant spotting | Filtre regex post-LLM + contrainte dans le prompt |
| Tokens illimités | rack-attack : throttle par `student_id` (N msg/min, M tokens/jour) |
| Rate limit différencié | Clé enseignant partagée → limite plus stricte par élève |
| PII mineurs | Jamais de logging du contenu message en clair ; logger : `student_id`, `conversation_id`, `model`, `tokens`, `latency_ms`, `error` |
| Clés API | `encrypts :api_key` déjà en place ; `User.openrouter_api_key` idem |

---

## §9 — Tests

### Pendant la refonte (par vague)

- **Tag** : specs tuteur existantes cassées → `xfeature` au début de chaque vague
- **Request specs** (`spec/requests/`) : statuts HTTP, mutations d'état, guards AASM, transitions refusées
- **Model specs** : `TutorState` — sérialisation/désérialisation, `with(...)`, clamp `discouragement_level`
- **Service specs** : chaque étape pipeline testée isolément, stubs `RubyLLM::Chat#ask`
- **Tool specs** : chaque tool LLM avec inputs valides/invalides, guards serveur

### En fin de chaque vague

- Features Capybara E2E pour le parcours élève complet de la vague
- Couvrent : activation tuteur, repérage, guidage socratique, auto-évaluation, feedback

### Infrastructure CI

```ruby
# spec/support/fake_ruby_llm.rb
RubyLLM.configure { |c| c.default_provider = :fake }
```

- VCR + WebMock pour cassettes d'intégration
- Streaming : stub `each_chunk` avec Array
- `WEBMOCK_DISABLE_NET=true` en CI obligatoire

---

## §10 — Périmètre hors-scope (cette refonte)

- Simulation tuteur-vs-LLM (`tutor_simulation/`) — maintenu tel quel
- RAG pgvector — post-MVP
- Observabilité avancée (Helicone, Langfuse) — indépendant
- Dashboard enseignant des conversations — feature séparée
- `StudentLearningProfile` transverse inter-sujets — post-MVP (cf. D3-C)
- Résumés ciblés par question — post-MVP (cf. D4-D)
- Coach vocal TTS, challenges inter-élèves, plan de révision pré-BAC

---

## §11 — Découpage en vagues

À définir après validation du spec (pattern REST doctrine : une vague = une PR mergeable et déployable indépendamment). Candidats probables :

- **Vague 1** : Schéma (migrations + modèles + Data.define `TutorState`) + suppression ancien code tuteur
- **Vague 2** : Pipeline LLM (POJO steps + ruby_llm + tools) + persistance messages
- **Vague 3** : Phase spotting (repérage libre + filtre regex + data_hints)
- **Vague 4** : UI Hotwire (drawer chat + streaming + auto-évaluation)
- **Vague 5** : Activation par classe (D11 — clé API multi-mode) + rate limiting
- **Vague 6** : Tests E2E complets + réécriture features Capybara

---

## Gems à ajouter

| Gem | Usage | Statut |
|---|---|---|
| `ruby_llm` | Client LLM unifié multi-provider | À ajouter |
| `aasm` | Machine à états lifecycle | À ajouter |
| `rack-attack` | Rate limiting par student_id | À ajouter |

Optionnels (décision indépendante) : `flipper`, `lograge`.
