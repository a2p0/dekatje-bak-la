# Tasks: REST Doctrine Wave 2 — Question Validation + Password Reset

**Input**: Design documents from `/specs/033-rest-validation-password/`
**Prerequisites**: plan.md, spec.md, research.md

**Tests**: Request specs + model specs + vérification feature specs existants. Pattern identique à vague 1.

**Organization**: 3 user stories (valider, invalider, reset password). Validate/invalidate partagent l'infrastructure (controller + routes + vues).

---

## Phase 1: Setup

Aucun setup — branche créée, code existant.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Méthodes métier Question + routes shallow. Prérequis pour toutes les US.

**CRITICAL**: Phase 2 bloque toutes les phases suivantes.

- [ ] T001 Ajouter `class InvalidTransition < StandardError` dans `app/models/question.rb`
- [ ] T002 Ajouter méthode `Question#validate!` dans `app/models/question.rb` — raise `InvalidTransition` si déjà validated, sinon `update!(status: :validated)`
- [ ] T003 Ajouter méthode `Question#invalidate!` dans `app/models/question.rb` — raise `InvalidTransition` si déjà draft, sinon `update!(status: :draft)`
- [ ] T004 [P] Étendre `spec/models/question_spec.rb` — tests `validate!` (happy + déjà validated) et `invalidate!` (happy + déjà draft)
- [ ] T005 Mettre à jour `config/routes.rb` — appliquer `shallow: true` sur `resources :parts` dans le bloc `resources :subjects`. Appliquer `shallow: true` sur `resources :students` dans le bloc `resources :classrooms`. Ajouter `resource :validation, only: [:create, :destroy], module: "questions"` dans le bloc `resources :questions`. Ajouter `resource :password_reset, only: [:create], module: "students"` dans le bloc `resources :students`. Supprimer les `member do post :reset_password end` et `member do patch :validate; patch :invalidate end` correspondants.

**Checkpoint**: Question model étendu. Routes RESTful + shallow en place. Les anciens helpers (validate_teacher_subject_part_question_path, etc.) n'existent plus — les vues existantes vont casser jusqu'à Phase 5.

---

## Phase 3: User Story 1 — Valider une question (Priority: P1) 🎯 MVP

**Goal**: Exposer `validate!` via `POST /teacher/questions/:question_id/validation`.

**Independent Test**: Créer une question `draft`, POST sur la nouvelle URL via request spec, vérifier status=validated et Turbo Stream response.

**Depends on**: Phase 2

- [ ] T006 [US1] Créer `app/controllers/teacher/questions/validations_controller.rb` — `Teacher::Questions::ValidationsController < Teacher::BaseController`, `before_action :set_question`, `rescue_from Question::InvalidTransition`, actions `create` et `destroy`, méthode privée `render_question_update` (voir plan.md Phase 3 pour la structure complète)
- [ ] T007 [US1] Mettre à jour `app/views/teacher/questions/_question.html.erb` — remplacer `button_to "Valider", validate_teacher_subject_part_question_path(s, p, q), method: :patch` par `button_to "Valider", teacher_question_validation_path(q), method: :post` (préserver toutes les autres options : data-turbo-frame, classes CSS, etc.)

**Checkpoint**: Publier une question fonctionne via la nouvelle URL. Le bouton "Invalider" est encore cassé (Phase 4).

---

## Phase 4: User Story 2 — Invalider une question (Priority: P1)

**Goal**: Exposer `invalidate!` via `DELETE /teacher/questions/:question_id/validation`.

**Independent Test**: Créer une question `validated`, DELETE sur la nouvelle URL, vérifier status=draft.

**Depends on**: Phase 2, Phase 3 (controller créé)

- [ ] T008 [US2] Mettre à jour `app/views/teacher/questions/_question.html.erb` — remplacer `button_to "Invalider", invalidate_teacher_subject_part_question_path(s, p, q), method: :patch` par `button_to "Invalider", teacher_question_validation_path(q), method: :delete` (préserver les autres options)

**Checkpoint**: Cycle valider/invalider complet fonctionnel via nouvelle URL.

---

## Phase 5: User Story 3 — Réinitialiser le mot de passe d'un élève (Priority: P1)

**Goal**: Exposer la réinitialisation via `POST /teacher/students/:student_id/password_reset`.

**Independent Test**: Cliquer "Réinitialiser mot de passe" sur un élève, vérifier qu'un nouveau mdp est généré et affiché.

**Depends on**: Phase 2 (routes)

- [ ] T009 [US3] Créer `app/controllers/teacher/students/password_resets_controller.rb` — `Teacher::Students::PasswordResetsController < Teacher::BaseController`, `before_action :set_student` (scoped via `current_user.classrooms`), action `create` qui appelle `ResetStudentPassword.call(student: @student)`, stocke les credentials en session, redirige vers `teacher_classroom_path(@student.classroom)` (voir plan.md Phase 4)
- [ ] T010 [US3] Mettre à jour `app/views/teacher/classrooms/show.html.erb` — remplacer `button_to ..., reset_password_teacher_classroom_student_path(@classroom, student), method: :post` par `button_to ..., teacher_student_password_reset_path(student), method: :post` (préserver data-turbo-confirm, classes, etc.)

**Checkpoint**: Reset password fonctionne via nouvelle URL.

---

## Phase 6: Migration des routes existantes shallow (affecte CRUD questions)

**Purpose**: Suite au `shallow: true`, les URLs `update`/`destroy` de questions sont passées de `/subjects/:s/parts/:p/questions/:id` à `/questions/:id`. Les vues et controllers doivent être mis à jour en conséquence.

**Depends on**: Phase 2

- [ ] T011 Mettre à jour `app/views/teacher/questions/_question.html.erb` — remplacer les 2 `button_to "Supprimer", teacher_subject_part_question_path(subject, part, question), method: :delete` (lignes 33, 59) par `button_to "Supprimer", teacher_question_path(question), method: :delete`
- [ ] T012 Mettre à jour `app/views/teacher/questions/_question_form.html.erb:1` — remplacer `form_with url: teacher_subject_part_question_path(subject, part, question), method: :patch` par `form_with url: teacher_question_path(question), method: :patch`
- [ ] T013a Adapter `set_question` dans `app/controllers/teacher/questions_controller.rb` pour signature shallow — remplacer `@question = @part.questions.kept.find_by(id: params[:id])` par `@question = Question.kept.joins(part: :subject).where(subjects: { owner_id: current_user.id }).find_by(id: params[:id])`, puis déduire `@part = @question.part` et `@subject = @part.subject` si non-nil. Retirer `before_action :set_subject, :set_part` du controller (plus nécessaires avec le scoping par la question).
- [ ] T013b Adapter la redirection dans `app/controllers/teacher/questions_controller.rb:70` — `redirect_to teacher_subject_part_path(@subject, @part)` devient `redirect_to teacher_part_path(@part)` (shallow member URL).
- [ ] T014a Mettre à jour `app/views/teacher/subjects/_parts_list.html.erb:43` — remplacer `teacher_subject_part_path(subject, part)` par `teacher_part_path(part)`
- [ ] T014b Mettre à jour `app/views/teacher/parts/show.html.erb:13` — remplacer `teacher_subject_part_path(@subject, part)` par `teacher_part_path(part)`
- [ ] T014c Mettre à jour `spec/features/teacher_question_validation_spec.rb` — 4 occurrences (lignes 37, 54, 74, 96) de `teacher_subject_part_path(subject_record, part)` → `teacher_part_path(part)`
- [ ] T014d Mettre à jour `spec/requests/teacher/parts_spec.rb` — 2 occurrences (lignes 12, 19) de `teacher_subject_part_path(...)` → `teacher_part_path(...)`

**Checkpoint**: Le CRUD questions (update, destroy) + la navigation vers parts fonctionnent avec les nouvelles routes shallow.

---

## Phase 7: Suppression du code ancien

**Depends on**: Phase 3, 4, 5, 6 (tous les callers migrés)

- [ ] T015 Supprimer les actions `validate` et `invalidate` de `app/controllers/teacher/questions_controller.rb`
- [ ] T016 Supprimer l'action `reset_password` de `app/controllers/teacher/students_controller.rb`. Supprimer aussi le `before_action :set_student, only: [:reset_password]` associé.
- [ ] T017 Nettoyer les `before_action` de `Teacher::QuestionsController` — retirer `set_subject` et `set_part` s'ils ne sont plus utilisés (après T013, le scoping se fait via `set_question` directement)

**Checkpoint**: Zéro action non-RESTful dans QuestionsController (validate/invalidate) ni StudentsController (reset_password).

---

## Phase 8: Tests

- [ ] T018 Créer `spec/requests/teacher/questions/validations_spec.rb` — scenarios : POST happy path (draft → validated, Turbo Stream response), POST déjà validated → Turbo Stream flash alert, DELETE happy path (validated → draft), DELETE déjà draft → alert, non-propriétaire → 404, question discarded → 404
- [ ] T019 Créer `spec/requests/teacher/students/password_resets_spec.rb` — scenarios : POST happy path (new password generated, credentials stored in session, redirect to classroom), non-propriétaire → 404, élève d'une autre classe → 404
- [ ] T020 Mettre à jour `spec/requests/teacher/questions_spec.rb` — retirer ou remplacer les tests des routes validate/invalidate par un commentaire pointant vers le nouveau spec. Adapter les tests `update`/`destroy` si leurs URLs ont changé avec shallow.
- [ ] T021 Mettre à jour `spec/requests/teacher/students_spec.rb` — retirer ou remplacer le test de `reset_password` par un commentaire pointant vers le nouveau spec.
- [ ] T022 Lancer `bundle exec rspec spec/features/teacher_question_validation_spec.rb spec/features/teacher_classroom_management_spec.rb` — doivent passer (labels stables)

**Checkpoint**: Couverture complète.

---

## Phase 9: Validation finale

- [ ] T023 Lancer la suite complète `bundle exec rspec` — vérifier 0 régression (1 failure pré-existante flaky sur global_navigation_spec:90 est OK)
- [ ] T024 Vérifier SC-001/SC-002/SC-003 : grep dans `app/` et `spec/` :
  - `validate_teacher_subject_part_question_path` → 0 occurrence
  - `invalidate_teacher_subject_part_question_path` → 0 occurrence
  - `reset_password_teacher_classroom_student_path` → 0 occurrence
  - `def validate\b` dans `app/controllers/teacher/questions_controller.rb` → 0 occurrence
  - `def invalidate\b` dans idem → 0 occurrence
  - `def reset_password\b` dans `app/controllers/teacher/students_controller.rb` → 0 occurrence
- [ ] T025 `bin/rubocop` → 0 offense
- [ ] T026 Push + créer la PR vers main

---

## Dependencies & Execution Order

```
Phase 1 (Setup)              vide
    ↓
Phase 2 (Foundational)       T001 → T002 → T003, T004 [P], T005
    ↓
Phase 3 (US1 Valider)        T006 → T007
    ↓
Phase 4 (US2 Invalider)      T008
    ↓
Phase 5 (US3 Password Reset) T009 → T010 (peut être parallèle à Phase 3/4)
    ↓
Phase 6 (Routes shallow CRUD) T011 [P], T012 [P], T013a → T013b, T014a/b/c/d [P]
    ↓
Phase 7 (Nettoyage)          T015, T016 [P], T017
    ↓
Phase 8 (Tests)              T018, T019 [P], T020, T021, T022
    ↓
Phase 9 (Validation)         T023 → T024 → T025 → T026
```

### Parallel Opportunities

- **Phase 2** : T004 (spec modèle) peut être écrit en parallèle des implémentations T001-T003
- **Phase 5** peut démarrer en parallèle des Phases 3/4 (resources indépendantes)
- **Phase 6** : T011 et T012 sur différents fichiers de vues [P]
- **Phase 7** : T015 et T016 sur différents controllers [P]
- **Phase 8** : T018 et T019 sur différents fichiers [P]

---

## Implementation Strategy

### MVP (US1+US2 ou US3)

- **US1+US2 ensemble** : validate/invalidate sont symétriques, livrés ensemble
- **US3 indépendant** : peut être mergé séparément si besoin

### Stratégie de sécurité du refactoring

Phase 2 casse les URLs des vues existantes temporairement. Les Phases 3, 4, 5, 6 restaurent la fonctionnalité en migrant les vues vers les nouveaux helpers. Phase 7 supprime le code ancien **une fois** que tous les callers ont migré.

Entre Phase 2 et Phase 6, le code ne compile pas totalement (helpers manquants dans les vues). C'est acceptable en refactoring par phases internes à une PR.

---

## Notes

- Tasks `[P]` peuvent être parallélisées via subagents
- Le pattern `Model#transition!` + `rescue_from` + `Namespace::Resource` est désormais réutilisable pour toutes les transitions
- **Shallow routing** est la nouveauté de cette vague — bien tester que `teacher_question_path` et `teacher_part_path` fonctionnent partout
- Feature specs existants servent de filet de sécurité (labels stables = pas de modif)
