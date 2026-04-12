# Implementation Plan: REST Doctrine Wave 2 — Question Validation + Password Reset

**Branch**: `033-rest-validation-password` | **Date**: 2026-04-12 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/033-rest-validation-password/spec.md`

## Summary

Migrer 3 actions custom vers des controllers RESTful :
- `Teacher::QuestionsController#validate/invalidate` → `Teacher::Questions::ValidationsController#create/destroy`
- `Teacher::StudentsController#reset_password` → `Teacher::Students::PasswordResetsController#create`

Introduire `Question#validate!/invalidate!` + `Question::InvalidTransition`.

Aplatir les routes profondes via `shallow: true` sur questions et students (aligné sur la doctrine REST).

## Technical Context

**Language/Version**: Ruby 3.3+ / Rails 8.1  
**Primary Dependencies**: Hotwire (Turbo Streams), Devise, ResetStudentPassword service existant  
**Storage**: PostgreSQL via Neon  
**Testing**: RSpec + FactoryBot + Capybara  
**Target Platform**: Linux server (Coolify/Nixpacks)  
**Project Type**: Web application fullstack Rails  
**Performance Goals**: N/A (refactoring)  
**Constraints**: CI GitHub Actions ; pattern vague 1 (PR #34) comme référence  
**Scale/Scope**: 1 modèle étendu (Question), 4 controllers touchés (2 nouveaux + 2 nettoyés), routes.rb, ~3 vues à migrer, 2 nouveaux request specs

## Constitution Check

| Principe | Statut | Notes |
|----------|--------|-------|
| I. Fullstack Rails — Hotwire Only | PASS | Turbo Streams pour validations ; redirect HTML pour password reset (cohérent avec vague 1) |
| II. RGPD & Protection des mineurs | PASS | Password reset préservé : aucun email, enseignant propriétaire uniquement |
| III. Security | PASS | Authorization via scoping `current_user.subjects` / `current_user.classrooms` |
| IV. Testing | PASS | Model specs + 2 request specs + feature specs existants |
| V. Performance & Simplicity | PASS | Routes plus courtes (shallow), code plus simple |
| VI. Development Workflow | PASS | Plan validé, branche feature, PR + CI |

## Project Structure

### Documentation (this feature)

```text
specs/033-rest-validation-password/
├── spec.md
├── plan.md              # This file
├── research.md
├── checklists/requirements.md
└── tasks.md             # (created by /speckit.tasks)
```

### Source Code (files impacted)

```text
app/
├── controllers/
│   └── teacher/
│       ├── questions_controller.rb          # Retirer validate/invalidate + before_actions
│       ├── questions/
│       │   └── validations_controller.rb    # NEW
│       ├── students_controller.rb           # Retirer reset_password + before_action
│       └── students/
│           └── password_resets_controller.rb # NEW
├── models/
│   └── question.rb                          # Ajouter InvalidTransition + validate!/invalidate!
└── views/
    └── teacher/
        ├── questions/
        │   ├── _question.html.erb           # 3 button_to à migrer (validate, invalidate, destroy)
        │   └── _question_form.html.erb      # form_with url à migrer (update)
        └── classrooms/
            └── show.html.erb                # button_to "Réinitialiser mot de passe" à migrer

config/
└── routes.rb                                # shallow: true sur questions+students, nouvelles resources

spec/
├── features/
│   ├── teacher_question_validation_spec.rb  # Doit passer sans modif (labels stables)
│   └── teacher_classroom_management_spec.rb # Doit passer sans modif
├── models/
│   └── question_spec.rb                     # Ajouter specs pour validate!/invalidate!
└── requests/
    └── teacher/
        ├── questions/
        │   └── validations_spec.rb          # NEW
        ├── questions_spec.rb                # Mettre à jour ou retirer les tests validate/invalidate
        ├── students/
        │   └── password_resets_spec.rb      # NEW
        └── students_spec.rb                 # Mettre à jour ou retirer les tests reset_password
```

## Implementation Phases

### Phase 1 — Modèle Question : méthodes métier et exception

Pattern identique à vague 1 (Subject). Ajouter `InvalidTransition`, `validate!`, `invalidate!`.

```ruby
class Question < ApplicationRecord
  class InvalidTransition < StandardError; end

  # ... existing code ...

  def validate!
    raise InvalidTransition, "Cette question est déjà validée." if validated?
    update!(status: :validated)
  end

  def invalidate!
    raise InvalidTransition, "Cette question est déjà en brouillon." if draft?
    update!(status: :draft)
  end
end
```

### Phase 2 — Routes : shallow + nouvelles resources

```ruby
resources :subjects, only: [:index, :new, :create, :show] do
  resources :parts, only: [:show], shallow: true do
    resources :questions, only: [:update, :destroy] do
      resource :validation, only: [:create, :destroy], module: "questions"
    end
  end
  member do
    post  :retry_extraction
    get   :assign
    patch :assign
  end
  resource :publication, only: [:create, :destroy], module: "subjects"
end

resources :classrooms, only: [:index, :new, :create, :show] do
  resources :students, only: [:index, :new, :create], shallow: true do
    collection do
      get  :bulk_new
      post :bulk_create
    end
    resource :password_reset, only: [:create], module: "students"
  end
  member do
    get :export_pdf
    get :export_markdown
  end
end
```

**URLs finales** :
- `PATCH /teacher/questions/:id` (update)
- `DELETE /teacher/questions/:id` (destroy)
- `POST   /teacher/questions/:question_id/validation` (validate)
- `DELETE /teacher/questions/:question_id/validation` (invalidate)
- `POST   /teacher/students/:student_id/password_reset` (reset_password)

### Phase 3 — Nouveau controller ValidationsController

Voir research.md R2. Turbo Stream only.

```ruby
class Teacher::Questions::ValidationsController < Teacher::BaseController
  before_action :set_question
  rescue_from Question::InvalidTransition, with: :invalid_transition

  def create
    @question.validate!
    render_question_update
  end

  def destroy
    @question.invalidate!
    render_question_update
  end

  private

  def set_question
    @question = Question.kept.joins(part: :subject)
                        .where(subjects: { owner_id: current_user.id })
                        .find(params[:question_id])
  end

  def render_question_update
    render turbo_stream: turbo_stream.replace(
      ActionView::RecordIdentifier.dom_id(@question),
      partial: "teacher/questions/question",
      locals: { question: @question, subject: @question.part.subject, part: @question.part }
    )
  end

  def invalid_transition(exception)
    render turbo_stream: turbo_stream.replace(
      "flash", partial: "shared/flash", locals: { alert: exception.message }
    )
  end
end
```

### Phase 4 — Nouveau controller PasswordResetsController

Voir research.md R6. Logique reprise de l'ancien `reset_password`.

### Phase 5 — Migration des vues

**`app/views/teacher/questions/_question.html.erb`** :
- `button_to "Valider", validate_teacher_subject_part_question_path(s, p, q), method: :patch`
  → `button_to "Valider", teacher_question_validation_path(q), method: :post`
- `button_to "Invalider", invalidate_teacher_subject_part_question_path(s, p, q), method: :patch`
  → `button_to "Invalider", teacher_question_validation_path(q), method: :delete`
- `button_to "Supprimer", teacher_subject_part_question_path(s, p, q), method: :delete`
  → `button_to "Supprimer", teacher_question_path(q), method: :delete`

**`app/views/teacher/questions/_question_form.html.erb`** :
- `form_with url: teacher_subject_part_question_path(s, p, q), method: :patch`
  → `form_with url: teacher_question_path(q), method: :patch`

**`app/views/teacher/classrooms/show.html.erb`** :
- `button_to reset_password_teacher_classroom_student_path(@classroom, student), method: :post`
  → `button_to teacher_student_password_reset_path(student), method: :post`

### Phase 6 — Suppression du code ancien

**`app/controllers/teacher/questions_controller.rb`** :
- Retirer `validate` et `invalidate` actions
- Adapter `before_action :set_subject, :set_part` qui ne doivent plus s'appliquer aux actions retirées (vérifier `only:` / sans `only:`)
- Les actions `update` et `destroy` restent dans ce controller. Comme la route est maintenant shallow, les params[:subject_id] et params[:part_id] ne sont plus passés. Il faut adapter le scoping :
  - Avant : `@subject = current_user.subjects.find(params[:subject_id])` puis `@part = @subject.parts.find(params[:part_id])` puis `@question = @part.questions.find(params[:id])`
  - Après : `@question = Question.kept.joins(part: :subject).where(subjects: { owner_id: current_user.id }).find(params[:id])` puis déduire `@subject = @question.part.subject` et `@part = @question.part` si nécessaire
- Adaptation nécessaire des redirections (`redirect_to teacher_subject_part_path(@subject, @part)` doit toujours fonctionner — pas de changement des routes de parts)

**`app/controllers/teacher/students_controller.rb`** :
- Retirer `reset_password` action
- Adapter `before_action :set_student, only: [:reset_password]` : retirer cette ligne

### Phase 7 — Tests

Voir research.md R8.

### Phase 8 — Validation finale

- `bundle exec rspec` — tous tests passent (modulo 1 flaky pré-existant)
- Grep `validate_teacher`, `invalidate_teacher`, `reset_password_teacher_classroom_student`, `teacher_subject_part_question` → zéro occurrence dans app/ et spec/
- Grep `def validate`, `def invalidate`, `def reset_password` dans les controllers migrés → zéro occurrence

## Risques et mitigations

| Risque | Impact | Mitigation |
|--------|--------|-----------|
| Shallow routing change les signatures `update`/`destroy` du controller QuestionsController | Moyen | Adapter `set_question` + éventuellement `set_subject`/`set_part` à la nouvelle signature |
| Routes `parts` également touchées par `shallow: true` (parts/:id devient top-level) | Moyen | Vérifier et mettre à jour les refs à `teacher_subject_part_path(s, p)` vs `teacher_part_path(p)` |
| Feature specs cassent si labels changent | Faible | Labels "Valider"/"Invalider"/"Réinitialiser mot de passe" préservés |
| Question#validate! conflit avec ActiveRecord#validate! | Faible | ActiveRecord n'a pas de `validate!` public — le nom est libre (mais surveiller) |
| Session generated_credentials préservée avec nouveau controller | Moyen | Copier la logique telle quelle, tester via feature spec existant |

## Scope Adjustments from Research

1. **Shallow également appliqué à `parts`** (indirect) — `resources :parts` imbriqué sous `subjects` doit accepter `shallow: true` pour que `shallow` descende à `questions`. L'URL member `show` passe de `teacher_subject_part_path(s, p)` à `teacher_part_path(p)`.
2. **Refs à `teacher_subject_part_path` à migrer** (grep exhaustif) : 4 fichiers touchés — `app/views/teacher/subjects/_parts_list.html.erb`, `app/views/teacher/parts/show.html.erb`, `spec/features/teacher_question_validation_spec.rb` (4 occurrences), `spec/requests/teacher/parts_spec.rb` (2 occurrences).
3. **Response controller Validations** : Turbo Stream only (pas de HTML fallback, cohérent avec l'usage actuel)
4. **Erreur transition** : via `turbo_stream.replace "flash"`, utilisant le partial existant
5. **Shallow sur students** (FR-011 mise à jour) : appliqué pour cohérence doctrinale bien qu'aucun member ne soit actuellement exposé. Prépare les futures vagues.

## Complexity Tracking

Aucune violation de constitution. Pattern validé en vague 1, réutilisé ici avec adaptation Turbo-only.
