# Research: REST Doctrine Wave 2 — Question Validation + Password Reset

**Date**: 2026-04-12 | **Branch**: `033-rest-validation-password`

## R1 — Pattern validate/invalidate

**Decision**: Utiliser le même pattern que vague 1 (`Subject#publish!`) :
- `Question#validate!` : raise si déjà validated, sinon `update!(status: :validated)`
- `Question#invalidate!` : raise si déjà draft, sinon `update!(status: :draft)`
- `Question::InvalidTransition < StandardError`

**Rationale**: Cohérence avec pattern établi. Ajoute une garde d'état qui fixe un bug latent (actuellement `update!(status: :validated)` sur déjà-validated passe silencieusement).

## R2 — Réponse du controller

**Decision**: Le controller actuel utilise **uniquement Turbo Stream** (pas de HTML redirect). Conserver ce comportement — c'est du Hotwire pur, correct. Pas de `respond_to` avec HTML fallback nécessaire.

**Rationale**: Les boutons validate/invalidate sont toujours cliqués depuis une page où le questionnaire est rendu en Turbo Frame. Le redirect HTML ne servirait à personne. Le controller vague 1 avait HTML+TS parce que publish redirige vers `assign`.

**Pattern** :
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
    # Rendre un turbo stream qui affiche un flash ? Ou un HTML fallback ?
    # Voir R3.
  end
end
```

## R3 — Erreur de transition : comment notifier l'utilisateur ?

**Decision**: Utiliser `turbo_stream.replace "flash"` avec un partial `shared/flash` (créé en vague 1). Pas de redirect HTML.

**Rationale**: Si l'utilisateur double-clique ou l'état change entre-temps, on doit lui montrer une erreur sans quitter la page. Le partial `shared/flash` existe déjà, il suffit de l'injecter via Turbo Stream.

```ruby
def invalid_transition(exception)
  render turbo_stream: turbo_stream.replace(
    "flash",
    partial: "shared/flash",
    locals: { alert: exception.message }
  )
end
```

## R4 — Shallow routing : impact sur les URL helpers existants

**Decision**: Appliquer `shallow: true` au `resources :questions` dans `config/routes.rb`. Cela affecte les URLs member existantes :

**Avant** (nesting complet) :
- `PATCH /teacher/subjects/:subject_id/parts/:part_id/questions/:id` → `teacher_subject_part_question_path(s, p, q)`
- `DELETE /teacher/subjects/:subject_id/parts/:part_id/questions/:id` → idem

**Après** (shallow) :
- `PATCH /teacher/questions/:id` → `teacher_question_path(q)`
- `DELETE /teacher/questions/:id` → `teacher_question_path(q)`
- `POST /teacher/questions/:question_id/validation` → `teacher_question_validation_path(q)`
- `DELETE /teacher/questions/:question_id/validation` → idem

**Fichiers à mettre à jour** :
- `app/views/teacher/questions/_question.html.erb` (button_to validate, invalidate, destroy)
- `app/views/teacher/questions/_question_form.html.erb` (form_with update)
- Potentiellement d'autres vues référençant les helpers — à grep

**Rationale**: Les URLs collection (index, create, new) n'existent pas pour questions dans ce projet (pas de `index` ni `create` pour questions — créées uniquement par extraction IA). Donc `shallow:` n'introduit pas de confusion collection/member.

## R5 — Shallow routing pour students

**Decision**: Appliquer `shallow: true` au `resources :students`.

**Avant** :
- Collection : `/teacher/classrooms/:classroom_id/students` (index, new, create) — imbriquées
- Member : `/teacher/classrooms/:classroom_id/students/:id/reset_password` — imbriquées

**Après** :
- Collection : `/teacher/classrooms/:classroom_id/students` (index, new, create) — restent imbriquées
- Member : `/teacher/students/:id` (show, edit, update, destroy) — top-level
- Resource imbriquée sur member : `POST /teacher/students/:student_id/password_reset` → `teacher_student_password_reset_path(s)`

**Note importante**: Students n'expose actuellement que `[:index, :new, :create]` + `:reset_password` + `bulk_*`. Il n'y a pas de `show`/`edit`/`update`/`destroy`. Le `shallow: true` ne change donc **rien aux routes existantes** (pas de member exposé à aplatir) — il n'affecte que la nouvelle resource `password_reset`.

**Conclusion** : Pour students, `shallow: true` est surtout conceptuel. On peut même s'en passer en nommant simplement la route à la main. Mais pour cohérence avec la doctrine et le pattern questions, on l'applique.

## R6 — Controller Teacher::Students::PasswordResetsController

**Decision**: Reprendre la logique existante du `reset_password` action, déplacée dans un controller dédié.

```ruby
class Teacher::Students::PasswordResetsController < Teacher::BaseController
  before_action :set_student

  def create
    password = ResetStudentPassword.call(student: @student)
    session[:generated_credentials] = [{
      "name" => "#{@student.first_name} #{@student.last_name}",
      "username" => @student.username,
      "password" => password
    }]
    redirect_to teacher_classroom_path(@student.classroom),
                notice: "Mot de passe réinitialisé. Notez le nouveau mot de passe ci-dessous."
  end

  private

  def set_student
    @student = Student.joins(:classroom)
                      .where(classrooms: { owner_id: current_user.id })
                      .find(params[:student_id])
  end
end
```

**Rationale**: 
- Authorization via scoping `classrooms.owner_id = current_user.id` (pattern Rails standard)
- Pas de Turbo Stream — la page de classroom se recharge pour afficher le nouveau password (c'est le comportement actuel)
- Pas d'exception custom (génération de mot de passe ne peut pas échouer sauf panne DB, rescue par le framework)

## R7 — Grep exhaustif des helpers existants à remplacer

**À remplacer** :
- `teacher_subject_part_question_path(s, p, q)` → `teacher_question_path(q)` (partout)
- `validate_teacher_subject_part_question_path(s, p, q)` → `teacher_question_validation_path(q)` avec method: :post
- `invalidate_teacher_subject_part_question_path(s, p, q)` → `teacher_question_validation_path(q)` avec method: :delete
- `reset_password_teacher_classroom_student_path(c, s)` → `teacher_student_password_reset_path(s)` avec method: :post

## R8 — Tests

**Decision**:
- **Question model spec** : ajouter 5 examples (`validate!` happy + déjà validated ; `invalidate!` happy + déjà draft + edge case)
- **Request spec nouveau** `spec/requests/teacher/questions/validations_spec.rb` : 6 scenarios (POST happy, POST déjà validated, DELETE happy, DELETE déjà draft, non-propriétaire → 404, question supprimée → 404)
- **Request spec nouveau** `spec/requests/teacher/students/password_resets_spec.rb` : 3 scenarios (POST happy, non-propriétaire → 404, student d'une autre classe → 404)
- **Feature specs existants** : vérifier qu'ils passent sans modif (labels "Valider"/"Invalider"/"Réinitialiser mot de passe" préservés)

## R9 — Nommage du controller pour Question::InvalidTransition

**Decision**: Définir `Question::InvalidTransition < StandardError` dans le modèle Question (pattern vague 1).

**Rationale**: Cohérence. Chaque modèle qui a des transitions a sa propre classe imbriquée.

## Résumé

| Item | Décision |
|------|---------|
| Pattern Question | `validate!`/`invalidate!` + `Question::InvalidTransition` |
| Réponse controller Validations | Turbo Stream uniquement (pas de HTML redirect) |
| Erreur transition | `turbo_stream.replace "flash"` avec alert |
| Shallow questions | OUI — affecte `update`/`destroy` URL helpers (à grep + remplacer) |
| Shallow students | OUI — conceptuel (pas de member existant à aplatir) |
| Controller PasswordResets | Logique copiée de l'ancien `reset_password`, scope authorization |
| Tests | Model specs + 2 nouveaux request specs |
