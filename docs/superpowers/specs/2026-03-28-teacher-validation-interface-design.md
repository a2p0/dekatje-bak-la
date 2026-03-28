# Design: Teacher Validation Interface (F5)

**Date**: 2026-03-28
**Branch**: `005-teacher-validation-interface`
**Scope**: Validation questions par partie, édition inline Turbo Frame, publication, assignation classes

---

## Architecture

Navigation par partie (Part) avec vue côte-à-côte questions + iframe PDF. Édition inline via Turbo Frames. Validation question par question. Publication conditionnelle (≥1 question validée). Page d'assignation classes accessible à tout moment.

---

## Nouvelle migration requise

`ClassroomSubject` — table de jointure Classroom ↔ Subject :
```
classroom_id: FK → classrooms
subject_id: FK → subjects
index unique composite [classroom_id, subject_id]
```

---

## Routes

```ruby
resources :subjects, only: [:index, :new, :create, :show] do
  resources :parts, only: [:show] do
    resources :questions, only: [:update, :destroy] do
      member do
        patch :validate
        patch :invalidate
      end
    end
  end
  member do
    patch :publish
    patch :archive
    patch :unpublish
    post  :retry_extraction
    get   :assign
    patch :assign
  end
end
```

---

## Controllers

### `Teacher::PartsController`
- `show` — charge la partie avec ses questions (kept), le sujet, le PDF énoncé

### `Teacher::QuestionsController`
- `update` — édite label, points, context_text + Answer (correction, explanation, key_concepts) via Turbo Frame
- `destroy` — soft delete (discarded_at = Time.current), retire la ligne via Turbo Stream
- `validate` — `status: :validated`, met à jour le Turbo Frame
- `invalidate` — `status: :draft`, met à jour le Turbo Frame

### `Teacher::SubjectsController` (modifications)
- `publish` — garde la logique existante + redirect vers `assign_teacher_subject_path`
- `unpublish` — `published → draft`
- `assign` GET — affiche les classes de l'enseignant avec état actuel
- `assign` PATCH — synchronise les ClassroomSubject (crée les manquantes, supprime les désélectionnées)

---

## Vues

### `app/views/teacher/parts/show.html.erb`
Layout deux colonnes :
- Gauche : navigation parties + liste questions (Turbo Frames)
- Droite : iframe PDF énoncé

### `app/views/teacher/questions/_question.html.erb`
Partial Turbo Frame `dom_id(question)` :
- Mode lecture : badge statut, label, points, correction, boutons (Modifier / Valider / Supprimer)
- Mode édition : formulaire inline avec textarea label, input points, textarea correction

### `app/views/teacher/subjects/_stats.html.erb`
Partial broadcasté : compteur questions validées + bouton Publier (disabled si 0)

### `app/views/teacher/subjects/assign.html.erb`
Checkboxes classes + bouton Enregistrer

---

## Modèles

### `ClassroomSubject`
```ruby
belongs_to :classroom
belongs_to :subject
```

### `Subject` (ajouts)
```ruby
has_many :classroom_subjects, dependent: :destroy
has_many :classrooms, through: :classroom_subjects

def validated_questions_count
  parts.joins(:questions).merge(Question.where(status: :validated).kept).count
end

def publishable?
  validated_questions_count > 0
end
```

### `Question` (ajout scope)
Déjà présent : `scope :kept` et enum status.

---

## Sécurité
- `Teacher::PartsController` et `Teacher::QuestionsController` héritent de `Teacher::BaseController`
- `set_subject` scoped à `current_teacher.subjects`
- `set_part` scoped à `@subject.parts`
- `set_question` scoped à `@part.questions.kept`

---

## Structure des fichiers

```
db/migrate/
  TIMESTAMP_create_classroom_subjects.rb

app/models/
  classroom_subject.rb
  subject.rb (modifié)

app/controllers/teacher/
  parts_controller.rb
  questions_controller.rb
  subjects_controller.rb (modifié)

app/views/teacher/
  parts/show.html.erb
  questions/_question.html.erb
  questions/_question_form.html.erb
  subjects/_stats.html.erb
  subjects/assign.html.erb
  subjects/show.html.erb (modifié)

spec/models/
  classroom_subject_spec.rb

spec/factories/
  classroom_subjects.rb

spec/requests/teacher/
  parts_spec.rb
  questions_spec.rb
```
