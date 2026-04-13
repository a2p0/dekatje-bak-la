# Implementation Plan: REST Doctrine Wave 5a — Student Actions

**Branch**: `036-rest-student-actions` | **Date**: 2026-04-13 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/036-rest-student-actions/spec.md`

## Summary

Migrer 6 actions custom student vers des controllers RESTful dédiés. Pattern éprouvé vagues 1-4, appliqué au scope student (avec `controller:` explicite au lieu de `module:`).

Vague 5a de la migration REST doctrine. Les 3 actions tuteur restantes (message, verify_spotting, skip_spotting) sont reportées à une vague 5b ultérieure quand le tuteur sera repensé.

## Technical Context

**Language/Version**: Ruby 3.3+ / Rails 8.1  
**Primary Dependencies**: Hotwire (Turbo Streams), existant `ValidateStudentApiKey` service, `StudentSession` model  
**Storage**: PostgreSQL via Neon (JSONB `progression` et `tutor_state` sur student_sessions)  
**Testing**: RSpec + FactoryBot + Capybara  
**Target Platform**: Linux server (Coolify/Nixpacks)  
**Project Type**: Web application fullstack Rails  
**Performance Goals**: Test key < 3s (limite API externe)  
**Constraints**: Scope student avec access_code préservé ; patterns vagues 1-4 comme référence  
**Scale/Scope**: 6 nouveaux controllers + 4 nettoyés, 10 migrations de helpers dans vues, 1 ligne JS

## Constitution Check

| Principe | Statut | Notes |
|----------|--------|-------|
| I. Fullstack Rails — Hotwire Only | PASS | Turbo Streams préservés pour reveal + test_key |
| II. RGPD & Protection des mineurs | PASS | Aucun changement de données student |
| III. Security | PASS | Authorization via `current_student.student_sessions` et `@classroom.subjects` — pattern existant préservé |
| IV. Testing | PASS | 6 request specs + feature specs existants préservés |
| V. Performance & Simplicity | PASS | Code plus modulaire (1 controller = 1 responsabilité) |
| VI. Development Workflow | PASS | Plan validé, branche feature, PR + CI |

## Project Structure

```text
app/
├── controllers/
│   └── student/
│       ├── subjects_controller.rb              # Retirer set_scope, complete_part, complete
│       ├── subjects/
│       │   ├── scope_selections_controller.rb  # NEW
│       │   ├── completions_controller.rb       # NEW
│       │   ├── part_completions_controller.rb  # NEW (nested sous parts)
│       │   └── tutor_activations_controller.rb # NEW
│       ├── questions_controller.rb             # Retirer reveal
│       ├── questions/
│       │   └── corrections_controller.rb       # NEW
│       ├── settings_controller.rb              # Retirer test_key
│       ├── settings/
│       │   └── api_key_tests_controller.rb     # NEW
│       └── tutor_controller.rb                 # Retirer activate (verify_spotting/skip_spotting restent)

config/routes.rb                                 # 6 anciennes routes supprimées, 6 resources ajoutées

app/javascript/controllers/settings_controller.js  # 1 ligne modifiée (URL test_key)

spec/
└── requests/
    └── student/
        ├── subjects/
        │   ├── scope_selections_spec.rb        # NEW
        │   ├── completions_spec.rb             # NEW
        │   ├── part_completions_spec.rb        # NEW
        │   └── tutor_activations_spec.rb       # NEW
        ├── questions/
        │   └── corrections_spec.rb             # NEW
        └── settings/
            └── api_key_tests_spec.rb           # NEW
```

## Implementation Phases

### Phase 1 — Routes

Mise à jour de `config/routes.rb`. Dans le bloc `scope "/:access_code", as: :student do` :

1. Supprimer les lignes anciennes :
   - `patch "/subjects/:id/set_scope", ..., as: :set_scope_subject`
   - `patch "/subjects/:id/complete_part/:part_id", ..., as: :complete_part_subject`
   - `patch "/subjects/:id/complete", ..., as: :complete_subject`
   - `patch "/subjects/:subject_id/questions/:id/reveal", ..., as: :reveal_question`
   - `post "/settings/test_key", ..., as: :test_key`
   - `scope ...tutor do post :activate, to: ... end` (SEULEMENT `activate`, pas verify/skip)

2. Ajouter les nouvelles resources (pattern ci-dessous, voir research.md R1)

**Note importante** : `settings` n'est pas une resource REST dans le scope actuel. Pour `api_key_test`, on ajoute une route manuelle ou on utilise `resource :api_key_test, only: [:create], path: "settings/api_key_test", controller: "student/settings/api_key_tests"`.

### Phase 2 — 6 Nouveaux Controllers

Créer 6 fichiers, un par resource :

1. `app/controllers/student/subjects/scope_selections_controller.rb` — action `update`
2. `app/controllers/student/subjects/completions_controller.rb` — action `create`
3. `app/controllers/student/subjects/part_completions_controller.rb` — action `create`
4. `app/controllers/student/subjects/tutor_activations_controller.rb` — action `create`
5. `app/controllers/student/questions/corrections_controller.rb` — action `create`
6. `app/controllers/student/settings/api_key_tests_controller.rb` — action `create`

Tous héritent de `Student::BaseController`. Logique copiée des actions actuelles (voir research.md R3).

### Phase 3 — Migration des vues

10 occurrences à migrer dans 5 fichiers (voir research.md R10) :

- `_scope_selection.html.erb` (3 boutons)
- `questions/show.html.erb` (3 boutons)
- `_correction_button.html.erb` (1 bouton)
- `_unanswered_questions.html.erb` (1 bouton)
- `_tutor_banner.html.erb` (1 bouton)

### Phase 4 — Migration JS

1 ligne à changer dans `app/javascript/controllers/settings_controller.js:47` : remplacer le substring `/settings/test_key` par `/settings/api_key_test`.

### Phase 5 — Nettoyage anciens controllers

1. `Student::SubjectsController` : retirer actions `set_scope`, `complete_part`, `complete`
2. `Student::QuestionsController` : retirer action `reveal`
3. `Student::SettingsController` : retirer action `test_key`
4. `Student::TutorController` : retirer action `activate` (garder `verify_spotting` et `skip_spotting`)

### Phase 6 — Tests

1. Créer 6 request specs couvrant :
   - Happy path (succès + redirection/turbo_stream attendu)
   - Authorization (404 ou redirect quand non-owner)
   - Cas edge pertinents par action (ex: `test_key` avec InvalidApiKeyError)

2. Vérifier les feature specs existants :
   - `student/subject_workflow_spec.rb`
   - `student_scope_selection_spec.rb`
   - `student_correction_reveal_spec.rb`
   - `student_api_key_configuration_spec.rb`
   - `student_tutor_activation_spec.rb`

   Ils doivent passer sans modification si les labels UI sont stables.

3. Mettre à jour les specs existants qui utilisent les anciens URL helpers directement.

### Phase 7 — Validation finale

- `bundle exec rspec` — 0 régression (modulo flakys pré-existants)
- Grep : 0 occurrence des anciens helpers (`set_scope_subject_path`, etc.)
- Grep : 0 occurrence de `def set_scope`, `def complete_part`, etc. dans les anciens controllers
- `bin/rubocop` → 0 offense

## Risques et mitigations

| Risque | Impact | Mitigation |
|--------|--------|-----------|
| JS URL fetch settings cassée | Moyen | Mise à jour ligne 47 explicite, test_key request spec |
| Feature spec cassé si URL helper utilisé | Faible | Grep exhaustif des helpers, tous identifiés dans R10 |
| Logique complete_part perdue (30 lignes redirection) | Moyen | Copy-paste verbatim, test e2e dans feature spec |
| Controller setting/api_key_test route bizarre | Faible | Syntax Rails valide avec `path:` explicite, testé via `rails routes` |

## Scope Adjustments from Research

Aucun. Cette vague a un scope clair et préservé depuis la spec.

## Complexity Tracking

Aucune violation de constitution. Réutilisation pure des patterns vagues 1-4. La seule subtilité est le scope `/:access_code` qui demande `controller:` explicite dans routes.rb — pattern déjà utilisé dans le projet pour `resources :conversations`.
