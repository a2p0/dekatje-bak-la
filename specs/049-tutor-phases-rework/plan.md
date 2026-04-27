# Implementation Plan: Refonte phases tuteur + answer_type

**Branch**: `049-tutor-phases-rework` | **Date**: 2026-04-25 | **Spec**: [spec.md](spec.md)

## Summary

Refonte du système de phases tuteur (7 → 9 états) et de la taxonomie `answer_type` (6 → 7 types). L'objectif est d'adapter le parcours pédagogique au type de question, de persister la phase par question (reprise sans régression), et d'introduire un greeting conditionnel (unique par sujet, re-greeting après 12h ou reconnexion).

## Technical Context

**Language/Version**: Ruby 3.3+, Rails 8.1.3
**Primary Dependencies**: RubyLLM (outils LLM), ActiveRecord (JSONB TutorState), RSpec + FactoryBot + Capybara
**Storage**: PostgreSQL via Neon — `conversations.tutor_state` (JSONB), `questions.answer_type` (integer enum)
**Testing**: RSpec (unit services), Capybara/Chrome (feature specs)
**Target Platform**: Rails fullstack, Hotwire/Turbo Streams
**Project Type**: web-service fullstack
**Constraints**: Pas de migration lourde — `TutorState` est JSONB extensible ; `answer_type` enum = migration nécessaire mais réversible

## Constitution Check

| Principe | Status | Note |
|----------|--------|------|
| I. Fullstack Rails Hotwire only | ✅ | Aucun SPA. Turbo Streams uniquement. |
| II. RGPD mineurs | ✅ | Pas de données personnelles nouvelles. |
| III. Security — clés chiffrées | ✅ | Pas de nouvelle clé API. |
| IV. TDD mandatory | ✅ | Specs avant code pour chaque service modifié. |
| V. Simplicité MVP | ✅ | Pas d'abstraction superflue. Extension JSONB sans migration schéma. |
| VI. Workflow — plan validé avant code | ✅ | Ce plan. |

## Project Structure

### Documentation (this feature)

```text
specs/049-tutor-phases-rework/
├── plan.md              ← ce fichier
├── research.md          ← Phase 0
├── data-model.md        ← Phase 1
└── tasks.md             ← /speckit.tasks
```

### Source Code (fichiers impactés)

```text
app/models/
├── tutor_state.rb              ← QuestionState + TutorState : nouveaux champs + phases
├── types/tutor_state_type.rb   ← sérialisation JSONB (compatible ascendante)
├── question.rb                 ← enum answer_type 6→7 valeurs

app/services/tutor/
├── apply_tool_calls.rb         ← TRANSITION_MATRIX + ALLOWED_PHASES + skip logic
├── build_context.rb            ← prompt adaptatif par phase + answer_type
├── tools/transition_tool.rb    ← description + param phase mis à jour

db/migrate/
└── YYYYMMDD_rename_answer_types.rb   ← migration enum + mapping

spec/models/
└── tutor_state_spec.rb         ← nouveaux états + skip logic

spec/services/tutor/
├── apply_tool_calls_spec.rb    ← nouvelles transitions, skip qcm
└── build_context_spec.rb       ← prompt par answer_type + phase

spec/features/
├── student_tutor_full_flow_spec.rb    ← mise à jour phases
├── student_tutor_spotting_spec.rb     ← spotting_type + spotting_data
└── student_tutor_activation_spec.rb  ← greeting conditionnel
```

---

## Phase 0 — Research

### R-001 : Mapping answer_type ancien → nouveau

| Ancien int | Ancien type | Nouvel int | Nouveau type | SQL UPDATE requis |
|-----------|-------------|-----------|--------------|-------------------|
| 0 | `text`          | 0 | `identification` | aucun (même int) |
| 1 | `calculation`   | 1 | `calcul`         | aucun (même int) |
| 2 | `argumentation` | 2 | `justification`  | aucun (même int) |
| 3 | `dr_reference`  | 3 | `representation` | aucun (même int) |
| 4 | `completion`    | 3 | `representation` | `UPDATE questions SET answer_type = 3 WHERE answer_type = 4` |
| 5 | `choice`        | 4 | `qcm`            | `UPDATE questions SET answer_type = 4 WHERE answer_type = 5` |
| _(n/a)_   | —           | 5 | `verification`   | aucun (nouveau type, pas en base) |
| _(n/a)_   | —           | 6 | `conclusion`     | aucun (nouveau type, pas en base) |

**Décision** : `dr_reference`(3) et `completion`(4) → tous deux `representation`(int 3). `choice`(5) → `qcm`(int 4). Les int finaux :

```ruby
enum :answer_type, {
  identification: 0,
  calcul:         1,
  justification:  2,
  representation: 3,
  qcm:            4,
  verification:   5,
  conclusion:     6
}
```

La migration renomme les valeurs en base via `UPDATE questions SET answer_type = ...` avec un mapping explicite.

### R-002 : Structure TutorState étendue

`TutorState` passe à :

```ruby
TutorState = Data.define(
  :current_phase,         # String — phase globale sujet (idle, greeting)
                          #          OU phase courante (enonce, spotting_type...)
                          #          pour compatibilité ascendante avec apply_tool_calls
  :current_question_id,
  :concepts_mastered,
  :concepts_to_revise,
  :discouragement_level,
  :question_states,       # Hash<String, QuestionState> — état par question
  :welcome_sent,          # Boolean — greeting sujet envoyé
  :last_activity_at       # String ISO8601 — pour re-greeting 12h
)
```

`QuestionState` passe à :

```ruby
QuestionState = Data.define(
  :phase,           # String — phase courante POUR CETTE QUESTION
                    # (enonce, spotting_type, spotting_data, guiding, validating, feedback, ended)
  :hints_used,
  :last_confidence,
  :error_types,
  :completed_at,
  :intro_seen
)
```

**Compatibilité ascendante** : les `QuestionState` existants en JSON n'ont pas de champ `phase` → deserialisation avec `phase: "enonce"` par défaut.

### R-003 : Nouvelle TRANSITION_MATRIX

```ruby
ALLOWED_PHASES = %w[
  idle greeting enonce spotting_type spotting_data guiding validating feedback ended
].freeze

TRANSITION_MATRIX = {
  "idle"          => %w[greeting],
  "greeting"      => %w[enonce],
  "enonce"        => %w[spotting_type guiding],   # skip spotting si qcm
  "spotting_type" => %w[spotting_data guiding],   # skip spotting_data si pas de DT/DR
  "spotting_data" => %w[guiding],
  "guiding"       => %w[validating enonce],        # enonce = retour question suivante
  "validating"    => %w[feedback ended],           # ended = skip feedback (clic correction)
  "feedback"      => %w[ended]
}.freeze

QUESTION_REQUIRED_PHASES = %w[enonce spotting_type spotting_data guiding validating feedback ended].freeze
```

### R-004 : Logique de skip

Le skip est décidé côté **prompt** (LLM appelle `transition` avec la bonne cible) ET garanti côté **apply_tool_calls** (la TRANSITION_MATRIX autorise le saut).

- QCM : `enonce → guiding` directement (pas de `spotting_type`)
- `justification`/`representation` sans `dt_dr_refs` : `spotting_type → guiding` (pas de `spotting_data`)
- Le prompt reçoit ces règles explicitement dans le contexte

### R-005 : Re-greeting conditionnel

Logique dans `BuildWelcomeMessage` (ou son équivalent) :
- Premier démarrage : `welcome_sent == false` → greeting + `welcome_sent: true`
- Reconnexion : détecté via `student_session` (nouveau login = nouvelle `StudentSession`)
- 12h d'inactivité : `Time.current - last_activity_at > 12.hours`

`last_activity_at` est mis à jour dans `UpdateTutorState` à chaque appel.

### R-006 : Reprise de phase par question

Quand un élève revient sur une question :
1. Charger `question_states[question_id.to_s]`
2. Si présent et `phase` défini → reprendre à cette phase (pas de reset vers `enonce`)
3. Si absent → démarrer à `enonce`

La logique de reprise est dans `ProcessMessage` / `BuildContext` (résolution de la phase courante depuis `question_states`).

---

## Phase 1 — Data Model & Contracts

Voir [data-model.md](data-model.md).

---

## Complexity Tracking

Aucune violation de constitution. Extension JSONB sans migration de schéma (seulement migration de données `answer_type`).
