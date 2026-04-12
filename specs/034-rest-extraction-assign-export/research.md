# Research: REST Doctrine Wave 3 — Extraction Retry, Assignment, Exports

**Date**: 2026-04-12 | **Branch**: `034-rest-extraction-assign-export`

## R1 — Sémantique et implémentation de "retry extraction"

**Decision**: `POST /teacher/subjects/:subject_id/extraction` — sémantique "créer une nouvelle run d'extraction". Le record `ExtractionJob` existant est **réutilisé** (pas de création DB), son status passe `failed → processing`. Nouveauté : **cleanup des specific parts orphelines** au niveau du service `PersistExtractedData`.

**Rationale**:
- `Subject has_one :extraction_job` → on ne crée pas un nouveau record, mais on reset l'existant
- Sémantique REST : `POST ..extraction` = "je veux une nouvelle run d'extraction" (pas un nouveau job persisté)
- Cleanup au niveau du service : idempotence par défaut, pas besoin de dupliquer dans le controller

**Pattern service** :
```ruby
class PersistExtractedData
  def call
    ActiveRecord::Base.transaction do
      # ... metadata ...
      # Common parts : guard existant préservé
      unless exam_session.common_parts.any?
        # ...
      end
      # Specific parts : cleanup AVANT recréation (idempotence)
      @subject.parts.specific.destroy_all
      Array(@data["specific_parts"]).each do |part_data|
        @subject.parts.create!(...)
      end
    end
  end
end
```

**Guard controller** : refuser retry si `processing` (pas de double-relance) ou `done` (pas de re-extraction d'un sujet déjà fait — évite la perte de données validées).

## R2 — Sémantique `assign` → `Assignment` resource

**Decision**: `resource :assignment, only: [:edit, :update]` (singular resource, 1 par subject).

**Rationale**:
- Mapping naturel de l'existant : `GET assign` → `edit`, `PATCH assign` → `update`
- Singular resource car 1 seul "formulaire d'assignation" par sujet (pas de collection)
- Controller `Teacher::Subjects::AssignmentsController` (pluriel par convention Rails)

**URLs** :
- `GET /teacher/subjects/:subject_id/assignment/edit` → affiche formulaire
- `PATCH /teacher/subjects/:subject_id/assignment` → met à jour les associations

**Vue** : la vue existante `subjects/assign.html.erb` est un formulaire simple. Deux options :
- **A** : déplacer en `subjects/assignments/edit.html.erb`
- **B** : laisser en place et pointer `render :assign` dans le nouveau controller

**Décision A** : déplacement propre. Cohérent avec la structure `publications/`, `validations/` mises en place vagues 1/2.

## R3 — Exports avec multiple formats

**Decision**: `resource :export, only: [:show]` sous classroom. Un seul controller avec `respond_to` pour les 2 formats.

**Pattern** :
```ruby
class Teacher::Classrooms::ExportsController < Teacher::BaseController
  before_action :set_classroom

  def show
    respond_to do |format|
      format.pdf do
        pdf = ExportStudentCredentialsPdf.call(classroom: @classroom)
        send_data pdf.render,
                  filename: "identifiants-#{@classroom.name.parameterize}.pdf",
                  type: "application/pdf", disposition: "attachment"
      end
      format.text do
        md = ExportStudentCredentialsMarkdown.call(classroom: @classroom)
        send_data md,
                  filename: "identifiants-#{@classroom.name.parameterize}.md",
                  type: "text/markdown", disposition: "attachment"
      end
    end
  end

  private

  def set_classroom
    @classroom = current_user.classrooms.find(params[:classroom_id])
  end
end
```

**URLs** :
- `GET /teacher/classrooms/:classroom_id/export.pdf`
- `GET /teacher/classrooms/:classroom_id/export.markdown`

**Note sur le format `markdown`** : Rails ne connaît pas nativement le format `markdown`. Deux options :
- **A** : utiliser `format.text` avec un type MIME custom (markdown n'est pas officiel IANA de toute façon — `text/markdown` existe mais peu reconnu)
- **B** : enregistrer `Mime::Type.register "text/markdown", :markdown` dans un initializer

**Décision B** : registrer le format `markdown` dans `config/initializers/mime_types.rb`. Plus explicite et permet `format.markdown do ... end`. URL : `/export.markdown` au lieu de `/export.text`.

## R4 — Guard state machine pour retry_extraction

**Decision**: Ajouter une méthode `Subject#retry_extraction!` ou lever directement dans le controller ? 

**Approche retenue** : la logique de retry touche `ExtractionJob.status` (pas Subject.status). Plus cohérent d'ajouter `ExtractionJob#reset_for_retry!` avec exception `ExtractionJob::InvalidRetry < StandardError`.

**Mais** : complexité ajoutée pour 3 règles simples (must be `failed`, not `processing`, not `done`). 

**Alternative pragmatique** : garder la logique dans le controller avec `rescue_from` si on veut quand même utiliser une exception. Pour cette vague, **approche simple** : `return` direct dans le controller avec redirect + alert (comportement actuel préservé, juste déplacé).

```ruby
class Teacher::Subjects::ExtractionsController < Teacher::BaseController
  before_action :set_subject

  def create
    job = @subject.extraction_job
    unless job&.failed?
      return redirect_to teacher_subject_path(@subject),
                         alert: "L'extraction ne peut être relancée que si elle a échoué."
    end

    job.update!(status: :processing, error_message: nil)
    ExtractQuestionsJob.perform_later(@subject.id)
    redirect_to teacher_subject_path(@subject), notice: "Extraction relancée."
  end

  private

  def set_subject
    @subject = current_user.subjects.find(params[:subject_id])
  end
end
```

**Simple et cohérent avec le comportement actuel**. Pas de nouvelle exception à créer.

## R5 — AssignmentsController

**Pattern retenu** :
```ruby
class Teacher::Subjects::AssignmentsController < Teacher::BaseController
  before_action :set_subject

  def edit
    @classrooms = current_user.classrooms.order(:name)
    @assigned_ids = @subject.classroom_ids
  end

  def update
    selected_ids = Array(params[:classroom_ids]).map(&:to_i)
    @subject.classroom_ids = selected_ids
    redirect_to teacher_subject_path(@subject), notice: "Assignation mise à jour."
  end

  private

  def set_subject
    @subject = current_user.subjects.find(params[:subject_id])
  end
end
```

**Vue `edit.html.erb`** : déplacer `subjects/assign.html.erb` → `subjects/assignments/edit.html.erb`. Adapter le form_with :
- `form_with url: teacher_subject_assignment_path(@subject), method: :patch`

## R6 — Cleanup idempotence dans PersistExtractedData

**Point d'insertion** (confirmé par research ligne 58) :

```ruby
# Specific parts: cleanup avant recréation (idempotence / retry-safe)
@subject.parts.specific.destroy_all
Array(@data["specific_parts"]).each_with_index do |part_data, idx|
  part = @subject.parts.create!(...)
end
```

Le `dependent: :destroy` sur `Part has_many :questions` et `Question has_one :answer` cascade proprement. Pas de DELETE orphelin.

**Test à ajouter** : vérifier qu'un `PersistExtractedData.call` sur un subject avec specific parts existantes en supprime les anciennes et les recrée.

## R7 — Autorisation dans les nouveaux controllers

**Decision**: Pattern uniforme — `current_user.subjects.find(params[:subject_id])` ou `current_user.classrooms.find(params[:classroom_id])`. Levée `ActiveRecord::RecordNotFound` → géré par Rails (404).

Pour les `find_by` retournant `nil` + redirect (ancien pattern) : passer à `find` pour cohérence (les autres controllers de vagues 1-2 utilisent `find`).

## R8 — Migration des boutons/liens

**Fichiers** :

| Fichier | Ligne | Avant | Après |
|---------|-------|-------|-------|
| `app/views/teacher/subjects/show.html.erb` | 45 | `href: assign_teacher_subject_path(subject)` | `href: edit_teacher_subject_assignment_path(subject)` |
| `app/views/teacher/subjects/_stats.html.erb` | 45 | idem | idem |
| `app/views/teacher/subjects/_extraction_status.html.erb` | 29 | `retry_extraction_teacher_subject_path(@subject), method: :post` | `teacher_subject_extraction_path(@subject), method: :post` |
| `app/views/teacher/classrooms/show.html.erb` | 69 | `export_pdf_teacher_classroom_path(classroom)` | `teacher_classroom_export_path(classroom, format: :pdf)` |
| `app/views/teacher/classrooms/show.html.erb` | 74 | `export_markdown_teacher_classroom_path(classroom)` | `teacher_classroom_export_path(classroom, format: :markdown)` |
| `app/views/teacher/subjects/assign.html.erb` | 8 | `form_with url: assign_teacher_subject_path(@subject)` | `form_with url: teacher_subject_assignment_path(@subject)` (+ déplacer fichier vers `subjects/assignments/edit.html.erb`) |

**Specs** :
- `spec/features/teacher_question_validation_spec.rb:147` : `visit assign_teacher_subject_path(subject_record)` → `visit edit_teacher_subject_assignment_path(subject_record)`
- `spec/requests/teacher/subjects/publications_spec.rb:27` : assert `redirect_to(assign_teacher_subject_path(...))` → `redirect_to(edit_teacher_subject_assignment_path(...))`
- `spec/features/teacher_classroom_management_spec.rb:162` : `export_pdf_teacher_classroom_path(classroom)` → `teacher_classroom_export_path(classroom, format: :pdf)`
- `spec/features/teacher_subject_upload_spec.rb:78+86` : retry scenarios — vérifier si le label de bouton est préservé (probablement oui car on ne change que le href)

## R9 — Controller SubjectsController redirect après publication

Dans vague 1, après `publish!`, le controller redirige vers `assign_teacher_subject_path(@subject)`. Cette URL disparaît dans vague 3.

**Action** : mettre à jour `app/controllers/teacher/subjects/publications_controller.rb` pour rediriger vers `edit_teacher_subject_assignment_path(@subject)`.

## Résumé

| Item | Décision |
|------|---------|
| Retry extraction | `POST /teacher/subjects/:subject_id/extraction` → `ExtractionsController#create` (guard `failed?`) |
| Cleanup parts orphelines | Dans `PersistExtractedData` (idempotence au niveau service) |
| Assignment | `resource :assignment, only: [:edit, :update]` + vue déplacée |
| Exports | `resource :export, only: [:show]` + `respond_to` 2 formats + MIME type markdown enregistré |
| Nouvelles exceptions | Aucune (pattern simple guard + redirect dans controller) |
| Vues à migrer | 6 fichiers (4 vues + 2 specs) + 1 redirect controller vague 1 |
