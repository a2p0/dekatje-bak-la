# Design: Subject Upload & Technical Documents

**Date**: 2026-03-26
**Branch**: `003-subject-upload-dt-dr`
**Scope**: Modèles Subject + ExtractionJob, upload 5 PDFs, interface teacher CRUD sujets

---

## Architecture

Upload unique en une fois : 5 PDFs obligatoires attachés directement au `Subject` via ActiveStorage. Pas de modèle `TechnicalDocument` dans ce scope. `ExtractionJob` créé automatiquement à la création du sujet (pipeline extraction en tâche #4).

---

## Modèles

### `Subject`

```
title: string, not null
year: string, not null
exam_type: integer (enum: bac:0, bts:1, autre:2)
specialty: integer (enum: tronc_commun:0, SIN:1, ITEC:2, EC:3, AC:4)
region: integer (enum: metropole:0, drom_com:1, polynesie:2, candidat_libre:3)
status: integer (enum: draft:0, pending_validation:1, published:2, archived:3), default: 0
presentation_text: text  ← rempli par l'extraction (tâche #4)
discarded_at: datetime   ← soft delete
owner_id: FK → users

ActiveStorage attachments (5 obligatoires):
  enonce_file           ← PDF énoncé du sujet
  dt_file               ← PDF Documents Techniques
  dr_vierge_file        ← PDF Document Réponse vierge
  dr_corrige_file       ← PDF Document Réponse corrigé
  questions_corrigees_file ← PDF Questions corrigées
```

**Associations :**
- `belongs_to :owner, class_name: "User"`
- `has_one :extraction_job, dependent: :destroy`

**Validations :**
- Présence : `title`, `year`, `exam_type`, `specialty`, `region`
- Fichiers attachés obligatoires (tous les 5)
- Content type : `application/pdf` uniquement
- Taille max : 20 MB par fichier

**Scope :** `kept` → `where(discarded_at: nil)`

**Transitions de statut :**
```
draft → pending_validation  (après extraction réussie, tâche #4)
pending_validation → published  (action publish enseignant)
published → archived  (action archive enseignant)
published → draft  (dépublication)
```

---

### `ExtractionJob`

```
status: integer (enum: pending:0, processing:1, done:2, failed:3), default: 0
raw_json: jsonb
error_message: text
provider_used: integer (enum: teacher:0, server:1)
subject_id: FK → subjects
```

**Associations :**
- `belongs_to :subject`

Créé automatiquement avec `status: :pending` lors du `create` du Subject.

---

## Routes

```ruby
namespace :teacher do
  resources :subjects, only: [:index, :new, :create, :show] do
    member do
      patch :publish
      patch :archive
    end
  end
end
```

---

## Controller Teacher::SubjectsController

- Hérite de `Teacher::BaseController`
- `index` — `current_teacher.subjects.kept.order(created_at: :desc)`
- `new` — `@subject = Subject.new`
- `create` — crée subject + ExtractionJob(pending), redirect show
- `show` — subject + extraction_job
- `publish` — `draft/pending_validation → published` (guard sur statut)
- `archive` — `published → archived` (guard sur statut)
- `set_subject` — `current_teacher.subjects.find_by(id: params[:id])`, redirect index si nil

---

## Vues

### `index`
Tableau : titre, spécialité, région, année, statut (badge), date création.
Lien "Nouveau sujet".

### `new`
Deux sections :
1. Informations : titre, année, exam_type (select), specialty (select), region (select)
2. Upload PDFs :
   - Énoncé du sujet (obligatoire)
   - Documents Techniques — DT (obligatoire)
   - Document Réponse vierge — DR (obligatoire)
   - Document Réponse corrigé (obligatoire)
   - Questions corrigées (obligatoire)

### `show`
- Infos sujet (titre, spécialité, région, année, statut badge)
- Section PDFs : 5 liens de téléchargement
- Section extraction : statut ExtractionJob + message d'erreur si failed
- Boutons selon statut : "Publier" (si pending_validation), "Archiver" (si published)

---

## User model update

Ajouter `has_many :subjects, foreign_key: :owner_id, dependent: :destroy`.

---

## Structure des fichiers

```
db/migrate/
  TIMESTAMP_create_subjects.rb
  TIMESTAMP_create_extraction_jobs.rb

app/models/
  subject.rb
  extraction_job.rb

app/controllers/teacher/
  subjects_controller.rb

app/views/teacher/subjects/
  index.html.erb
  new.html.erb
  show.html.erb

spec/models/
  subject_spec.rb
  extraction_job_spec.rb

spec/factories/
  subjects.rb
  extraction_jobs.rb

spec/requests/teacher/
  subjects_spec.rb
```
