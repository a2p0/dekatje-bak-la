# Tasks: REST Doctrine Wave 5a — Student Actions

**Input**: Design documents from `/specs/036-rest-student-actions/`
**Prerequisites**: plan.md, spec.md, research.md

**Tests**: 6 nouveaux request specs + vérification feature specs existants.

**Organization**: 6 user stories indépendantes partageant `Student::BaseController` comme infrastructure.

---

## Phase 1: Setup

Aucun setup.

---

## Phase 2: Foundational

Aucun modèle ou service à modifier. `Student::BaseController` existant est réutilisé tel quel.

---

## Phase 3: Routes

**Purpose**: Repositionner les 6 actions en resources REST.

- [ ] T001 Mettre à jour `config/routes.rb` dans le bloc `scope "/:access_code", as: :student do` :
  **Supprimer** (6 routes) :
  - `patch "/subjects/:id/set_scope", to: "student/subjects#set_scope", as: :set_scope_subject`
  - `patch "/subjects/:id/complete_part/:part_id", to: "student/subjects#complete_part", as: :complete_part_subject`
  - `patch "/subjects/:id/complete", to: "student/subjects#complete", as: :complete_subject`
  - `patch "/subjects/:subject_id/questions/:id/reveal", to: "student/questions#reveal", as: :reveal_question`
  - `post "/settings/test_key", to: "student/settings#test_key", as: :test_key`
  - Dans `scope "/subjects/:subject_id/tutor", as: :tutor do` : supprimer `post :activate, to: "student/tutor#activate"` (garder le scope si verify/skip_spotting sont toujours dedans)

  **Ajouter** (5 resources imbriquées) — à l'intérieur du bloc `resources :subjects` :
  - `resource :scope_selection, only: [:update], controller: "student/subjects/scope_selections"`
  - `resource :completion, only: [:create], controller: "student/subjects/completions"`
  - `resource :tutor_activation, only: [:create], controller: "student/subjects/tutor_activations"`
  - Dans `resources :parts, only: []` imbriqué : `resource :part_completion, only: [:create], controller: "student/subjects/part_completions"`
  - Dans `resources :questions, only: [:show]` imbriqué : `resource :correction, only: [:create], controller: "student/questions/corrections"`

  **Ajouter** 1 resource pour settings (hors `resources :subjects`) :
  - `resource :api_key_test, only: [:create], path: "settings/api_key_test", controller: "student/settings/api_key_tests"`

  **Vérifier** : `bundle exec rails routes` montre les 6 nouvelles routes avec les noms helpers attendus (`student_subject_scope_selection_path`, etc.).

**Checkpoint**: Routes en place. Les vues et controllers ne sont pas encore migrés → les callers cassent jusqu'à Phases 4-5.

---

## Phase 4: User Story 1 — Choisir son périmètre (Priority: P1) 🎯

**Goal**: `PATCH /:access_code/subjects/:subject_id/scope_selection` fonctionne.

**Independent Test**: Sur une page sujet avec scope selection, cliquer une option, vérifier que `part_filter` et `scope_selected` sont mis à jour.

- [ ] T002 [US1] Créer `app/controllers/student/subjects/scope_selections_controller.rb` — hérite de `Student::BaseController`, `before_action :set_subject` (via `@classroom.subjects.published.find(params[:subject_id])`), action `update` qui trouve `session_record` via `current_student.student_sessions.find_by!(subject: @subject)`, appelle `update!(part_filter: params[:part_filter], scope_selected: true)`, redirect vers `student_subject_path`
- [ ] T003 [P] [US1] Mettre à jour `app/views/student/subjects/_scope_selection.html.erb` — lignes 10, 28, 46 : remplacer `student_set_scope_subject_path(...)` par `student_subject_scope_selection_path(access_code:, subject_id:)` avec `method: :patch`

---

## Phase 5: User Story 2 — Compléter une partie (Priority: P1)

**Goal**: `POST /:access_code/subjects/:subject_id/parts/:part_id/part_completion` fonctionne.

**Independent Test**: Atteindre la dernière question d'une partie, cliquer "Fin de la partie", vérifier redirection vers partie suivante.

- [ ] T004 [US2] Créer `app/controllers/student/subjects/part_completions_controller.rb` — hérite de `Student::BaseController`, action `create` qui reprend la logique complète de `Student::SubjectsController#complete_part` (ligne 114-175 actuelle) : trouve `@subject`, `@session_record`, appelle `mark_part_completed!(params[:part_id])`, puis calcule la redirection selon l'état du parcours (toutes parts complétées vs partie suivante dans section vs section opposée). COPIE VERBATIM de la logique existante pour éviter régressions.
- [ ] T005 [P] [US2] Mettre à jour `app/views/student/questions/show.html.erb` — lignes 188 et 228 : remplacer `student_complete_part_subject_path(..., id: @subject.id, part_id: @part.id)` par `student_subject_part_part_completion_path(access_code:, subject_id: @subject.id, part_id: @part.id)` avec `method: :post` (au lieu de `:patch`)

---

## Phase 6: User Story 3 — Compléter un sujet (Priority: P1)

**Goal**: `POST /:access_code/subjects/:subject_id/completion` fonctionne.

**Independent Test**: Sur la page des questions non répondues, cliquer "Terminer le sujet", vérifier marquage completed.

- [ ] T006 [US3] Créer `app/controllers/student/subjects/completions_controller.rb` — hérite de `Student::BaseController`, action `create` qui trouve `@subject` et `session_record`, appelle `mark_subject_completed!`, redirect vers `student_subject_path(..., completed: true)`
- [ ] T007 [P] [US3] Mettre à jour `app/views/student/subjects/_unanswered_questions.html.erb:22` — remplacer `student_complete_subject_path(...)` par `student_subject_completion_path(access_code:, subject_id: @subject.id)` avec `method: :post`

---

## Phase 7: User Story 4 — Révéler la correction (Priority: P1)

**Goal**: `POST /:access_code/subjects/:subject_id/questions/:id/correction` fonctionne en Turbo Stream.

**Independent Test**: Cliquer "Voir la correction", vérifier affichage dynamique et marquage answered.

- [ ] T008 [US4] Créer `app/controllers/student/questions/corrections_controller.rb` — hérite de `Student::BaseController`, `before_action` pour trouver `@subject`, `@question`, `@session_record`. Action `create` qui appelle `session_record.mark_answered!(@question.id)` et `render turbo_stream: turbo_stream.replace("question_#{@question.id}_correction", partial: "student/questions/correction", locals: {...})`
- [ ] T009 [P] [US4] Mettre à jour `app/views/student/questions/show.html.erb:154` — remplacer `student_reveal_question_path(...)` par `student_subject_question_correction_path(access_code:, subject_id: @subject.id, question_id: @question.id)` avec `method: :post`
- [ ] T010 [P] [US4] Mettre à jour `app/views/student/questions/_correction_button.html.erb:5` — même substitution

---

## Phase 8: User Story 5 — Tester une clé API (Priority: P2)

**Goal**: `POST /:access_code/settings/api_key_test` fonctionne en Turbo Stream.

**Independent Test**: Depuis réglages, saisir clé et cliquer "Tester", vérifier feedback Turbo Stream.

- [ ] T011 [US5] Créer `app/controllers/student/settings/api_key_tests_controller.rb` — hérite de `Student::BaseController`, action `create` qui reprend la logique actuelle de `Student::SettingsController#test_key` (appel `ValidateStudentApiKey.call` + rescue `InvalidApiKeyError`, render Turbo Stream avec HTML inline coloré). COPIE VERBATIM.
- [ ] T012 [US5] Mettre à jour `app/javascript/controllers/settings_controller.js:47` — remplacer `window.location.pathname.replace("/settings", "/settings/test_key")` par `window.location.pathname.replace("/settings", "/settings/api_key_test")`

---

## Phase 9: User Story 6 — Activer le tuteur (Priority: P2)

**Goal**: `POST /:access_code/subjects/:subject_id/tutor_activation` fonctionne.

**Independent Test**: Depuis la page sujet, cliquer "Activer le tuteur", vérifier `mode: :tutored`.

- [ ] T013 [US6] Créer `app/controllers/student/subjects/tutor_activations_controller.rb` — hérite de `Student::BaseController`, action `create` qui reprend la logique actuelle de `Student::TutorController#activate` : `find_or_create_by!` session record avec `mode: :tutored` si pas déjà tutored, redirect avec notice
- [ ] T014 [P] [US6] Mettre à jour `app/views/student/tutor/_tutor_banner.html.erb:16` — remplacer `student_tutor_activate_path(access_code:, subject_id:)` par `student_subject_tutor_activation_path(access_code:, subject_id:)` avec `method: :post`

---

## Phase 10: Nettoyage anciens controllers

**Depends on**: Phases 3-9 (tous les callers migrés)

- [ ] T015 Supprimer de `app/controllers/student/subjects_controller.rb` les actions `set_scope`, `complete_part`, `complete` (~60 lignes). Ajuster `before_action` si applicable. Retirer les méthodes privées associées si elles ne sont plus utilisées.
- [ ] T016 Supprimer de `app/controllers/student/questions_controller.rb` l'action `reveal`. Vérifier `before_action :set_question` usage.
- [ ] T017 Supprimer de `app/controllers/student/settings_controller.rb` l'action `test_key`.
- [ ] T018 Supprimer de `app/controllers/student/tutor_controller.rb` l'action `activate` et sa méthode privée `set_subject` si elle n'est plus utilisée ailleurs dans ce controller. Garder `verify_spotting` et `skip_spotting`.

**Checkpoint**: Zéro action non-RESTful dans les 4 controllers (excepté verify_spotting/skip_spotting reportés).

---

## Phase 11: Tests

- [ ] T019 [P] Créer `spec/requests/student/subjects/scope_selections_spec.rb` — scenarios : PATCH happy path avec différentes valeurs de part_filter ; PATCH avec session inexistante → erreur attendue ; 404 pour subject d'autre classe.
- [ ] T020 [P] Créer `spec/requests/student/subjects/completions_spec.rb` — scenarios : POST happy path, redirect avec `completed: true` ; 404 non-owner.
- [ ] T021 [P] Créer `spec/requests/student/subjects/part_completions_spec.rb` — scenarios : POST happy path sur partie intermédiaire (redirect vers section suivante) ; POST sur dernière partie (redirect vers subject) ; 404 non-owner.
- [ ] T022 [P] Créer `spec/requests/student/subjects/tutor_activations_spec.rb` — scenarios : POST happy path (autonomous → tutored) ; POST idempotent (déjà tutored) ; 404 non-owner.
- [ ] T023 [P] Créer `spec/requests/student/questions/corrections_spec.rb` — scenarios : POST happy path (Turbo Stream response, mark_answered appelé) ; 404 non-owner.
- [ ] T024 [P] Créer `spec/requests/student/settings/api_key_tests_spec.rb` — scenarios : POST avec clé valide (Turbo Stream success message), POST avec InvalidApiKeyError (Turbo Stream error message) ; 404 si pas authenticated.
- [ ] T025 Lancer les feature specs impactés pour s'assurer qu'ils passent sans modification :
  - `spec/features/student/subject_workflow_spec.rb`
  - `spec/features/student_scope_selection_spec.rb`
  - `spec/features/student_correction_reveal_spec.rb`
  - `spec/features/student_api_key_configuration_spec.rb`
  - `spec/features/student_tutor_activation_spec.rb`
- [ ] T026 Mettre à jour les specs qui utilisent directement les anciens URL helpers (grep `_reveal_`, `_set_scope_`, `_complete_subject_`, `_complete_part_`, `_test_key_`, `_tutor_activate_` dans spec/)

---

## Phase 12: Validation finale

- [ ] T027 Lancer la suite complète `bundle exec rspec` — 0 régression (modulo flakys pré-existants)
- [ ] T028 Vérifier critères de succès :
  - `grep -rn "set_scope_subject_path\|complete_part_subject_path\|complete_subject_path\|reveal_question_path\|test_key_path\|tutor_activate_path" app/ spec/` → 0 occurrence
  - `grep -n "def set_scope\|def complete_part\|def complete\|def reveal\|def test_key\|def activate" app/controllers/student/` → 0 occurrence (sauf `activate` si conservée ailleurs)
- [ ] T029 `bin/rubocop` → 0 offense
- [ ] T030 Push + créer la PR vers main

---

## Dependencies & Execution Order

```
Phase 1-2 (Setup/Foundational)       vide
    ↓
Phase 3 (Routes)                     T001
    ↓
Phase 4 (US1 Scope)                  T002 → T003
Phase 5 (US2 PartComplete)           T004 → T005
Phase 6 (US3 Complete)               T006 → T007
Phase 7 (US4 Correction)             T008 → T009, T010
Phase 8 (US5 ApiKeyTest)             T011 → T012
Phase 9 (US6 TutorActivation)        T013 → T014
  (Phases 4-9 peuvent être faites en parallèle après Phase 3)
    ↓
Phase 10 (Nettoyage)                 T015, T016, T017, T018 [P]
    ↓
Phase 11 (Tests)                     T019-T024 [P], T025, T026
    ↓
Phase 12 (Validation)                T027 → T028 → T029 → T030
```

### Parallel Opportunities

- **Phase 4-9** : 6 user stories indépendantes (6 controllers + 6 vues sur fichiers différents). Peuvent être parallélisées après Phase 3.
- **Phase 10** : les 4 controllers nettoyés sont indépendants.
- **Phase 11** : 6 request specs indépendants.

### Séquentialité critique

Phase 3 (routes) doit venir AVANT Phases 4-9 (sinon les controllers référencent des routes inexistantes). Phase 10 (nettoyage) doit venir APRÈS Phases 4-9 (sinon les anciennes actions disparaissent avant que les vues ne soient migrées).

---

## Implementation Strategy

### Dispatching parallel agents (optional)

Les 6 controllers + leurs vues peuvent être créés en parallèle via subagents :
- Un subagent par user story (US1-US6)
- Chacun crée son controller + met à jour sa/ses vue(s)
- Synchronisation post-parallel : Phase 10 (nettoyage central) + Phase 11 (tests centralisés)

### Incremental delivery

Toutes les 6 user stories sont indépendantes côté code mais interdépendantes côté routes (Phase 3). Livraison en une seule PR = plus simple.

---

## Notes

- Pattern `controller:` explicite dans routes (au lieu de `module:`) car scope student avec `/:access_code`
- Logique métier des actions complexes (surtout `complete_part`) : **copy-paste verbatim**, pas de refactor gratuit
- `TutorActivation` idempotent : guard `unless tutored?` préservé
- `ApiKeyTest` : aucune persistence, juste validation + Turbo Stream response
- Les 3 actions tuteur restantes (message, verify_spotting, skip_spotting) sont HORS SCOPE de cette vague
