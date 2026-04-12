# Tasks: REST Doctrine Wave 4 — Student Import

**Input**: Design documents from `/specs/035-rest-student-import/`
**Prerequisites**: plan.md, spec.md, research.md

**Tests**: 1 nouveau request spec + vérification feature spec existant.

**Organization**: 2 user stories partagent la même infrastructure (controller unique).

---

## Phase 1: Setup

Aucun setup.

---

## Phase 2: Foundational

Aucun prérequis fondationnel (pas de modèle modifié, pas de service modifié, réutilise `GenerateStudentCredentials` existant).

---

## Phase 3: User Story 1 + 2 — Student Import (Priority: P1) 🎯

**Goal**: Exposer l'import en lot via `GET /teacher/classrooms/:classroom_id/student_import/new` (formulaire) et `POST /teacher/classrooms/:classroom_id/student_import` (soumission).

**Independent Test**: Cliquer "Ajout en lot" → formulaire s'affiche. Soumettre 3 lignes → 3 élèves créés + credentials affichés.

### Implementation

- [ ] T001 [US1+US2] Mettre à jour `config/routes.rb` — dans le bloc `resources :students, only: [:index, :new, :create], shallow: true do`, supprimer `collection do get :bulk_new; post :bulk_create; end`. Ajouter `resource :student_import, only: [:new, :create], module: "classrooms"` à l'intérieur du bloc `resources :classrooms`.
- [ ] T002 [US1+US2] Créer `app/controllers/teacher/classrooms/student_imports_controller.rb` — `Teacher::Classrooms::StudentImportsController < Teacher::BaseController`, `before_action :set_classroom` scopé via `current_user.classrooms.find(params[:classroom_id])`. Actions `new` (vide) et `create` (copie de la logique `bulk_create` actuelle : parse textarea, boucle avec `GenerateStudentCredentials.call`, stocke credentials en session, redirige vers classroom avec notice/alert).
- [ ] T003 [US1] Déplacer `app/views/teacher/students/bulk_new.html.erb` → `app/views/teacher/classrooms/student_imports/new.html.erb` via `git mv`. Dans la vue déplacée, remplacer `form_with url: bulk_create_teacher_classroom_students_path(@classroom), method: :post` par `form_with url: teacher_classroom_student_import_path(@classroom), method: :post`. Conserver tout le reste.
- [ ] T004 [P] [US1] Mettre à jour `app/views/teacher/classrooms/show.html.erb:64` — remplacer `href: bulk_new_teacher_classroom_students_path(@classroom)` par `href: new_teacher_classroom_student_import_path(@classroom)`. Label "Ajout en lot" inchangé.

**Checkpoint**: Formulaire d'import accessible via nouvelle URL, soumission crée les élèves via nouvelle URL.

---

## Phase 4: Nettoyage

- [ ] T005 Supprimer les actions `bulk_new` et `bulk_create` de `app/controllers/teacher/students_controller.rb`. Le `before_action :set_classroom` reste (utilisé par `new` et `create`).

**Checkpoint**: Zéro action bulk_* dans StudentsController.

---

## Phase 5: Tests

- [ ] T006 [P] Créer `spec/requests/teacher/classrooms/student_imports_spec.rb` — scenarios :
  (a) GET new happy path (200, render, pour classroom owner)
  (b) POST happy path (textarea avec 3 lignes valides → 3 élèves créés, credentials en session, redirect vers classroom avec notice)
  (c) POST ligne invalide (ex: "Prénom" sans nom) → flash alert, autres lignes traitées
  (d) POST textarea vide → redirect vers classroom, zéro élève créé, pas d'erreur serveur
  (e) GET new sur classroom non-owner → 404
  (f) POST sur classroom non-owner → 404
- [ ] T007 [P] Mettre à jour `spec/requests/teacher/students_spec.rb` — retirer les `describe` des actions `bulk_new` et `bulk_create` (remplacées par le nouveau spec). Ajouter commentaire : "# Bulk import coverage moved to spec/requests/teacher/classrooms/student_imports_spec.rb".
- [ ] T008 Vérifier que `spec/features/teacher_classroom_management_spec.rb` passe (label "Ajout en lot" inchangé, le click_link doit continuer de fonctionner avec la nouvelle URL sous-jacente).

**Checkpoint**: Couverture complète, feature spec stable.

---

## Phase 6: Validation finale

- [ ] T009 Lancer la suite complète `bundle exec rspec` — 0 régression (modulo flakys pré-existants connus)
- [ ] T010 Vérifier critères de succès :
  - `grep -rn "bulk_new_teacher_classroom_students_path" app/ spec/` → 0 occurrence
  - `grep -rn "bulk_create_teacher_classroom_students_path" app/ spec/` → 0 occurrence
  - `grep -n "def bulk_new\|def bulk_create" app/controllers/teacher/students_controller.rb` → 0 occurrence
- [ ] T011 `bin/rubocop` → 0 offense
- [ ] T012 Push + créer la PR vers main

---

## Dependencies & Execution Order

```
Phase 1 (Setup)           vide
Phase 2 (Foundational)    vide
    ↓
Phase 3 (US1+US2)         T001 → T002 → T003, T004 [P]
    ↓
Phase 4 (Nettoyage)       T005
    ↓
Phase 5 (Tests)           T006, T007 [P] ; T008
    ↓
Phase 6 (Validation)      T009 → T010 → T011 → T012
```

### Parallel Opportunities

- **Phase 3** : T004 (vue classroom) parallélisable avec T003 (vue imports — fichiers différents)
- **Phase 5** : T006 et T007 parallélisables (fichiers différents)

---

## Implementation Strategy

Vague la plus simple : pas de foundational, pas de nouveau pattern, logique préservée. Tout est dans une seule US (2 sous-stories partageant la même infrastructure).

---

## Notes

- Pattern `GenerateStudentCredentials` service déjà en place depuis vague 1 rails-conventions
- Label "Ajout en lot" stable : feature spec passera sans modification
- Estimation : ~30 min d'implémentation + CI
