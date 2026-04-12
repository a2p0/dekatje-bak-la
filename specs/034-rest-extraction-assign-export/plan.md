# Implementation Plan: REST Doctrine Wave 3

**Branch**: `034-rest-extraction-assign-export` | **Date**: 2026-04-12 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/034-rest-extraction-assign-export/spec.md`

## Summary

Migrer 4 actions custom vers des controllers RESTful :
- `retry_extraction` → `Teacher::Subjects::ExtractionsController#create`
- `assign` (GET+PATCH) → `Teacher::Subjects::AssignmentsController#edit+update`
- `export_pdf` + `export_markdown` → `Teacher::Classrooms::ExportsController#show` avec 2 formats via `respond_to`

Introduction de 3 patterns nouveaux (vs vagues 1-2) :
- `edit`/`update` sur singular resource
- `show` avec multiples formats (MIME type markdown enregistré)
- **Idempotence dans un service partagé** (PersistExtractedData fixe bug de doublons au retry)

Vague 3/5 de la migration REST doctrine.

## Technical Context

**Language/Version**: Ruby 3.3+ / Rails 8.1  
**Primary Dependencies**: Hotwire, Devise, Sidekiq, Prawn (PDF), existing export services  
**Storage**: PostgreSQL via Neon  
**Testing**: RSpec + FactoryBot + Capybara  
**Target Platform**: Linux server (Coolify/Nixpacks)  
**Project Type**: Web application fullstack Rails  
**Performance Goals**: N/A (refactoring)  
**Constraints**: CI GitHub Actions ; patterns vagues 1-2 comme référence  
**Scale/Scope**: 1 service modifié (PersistExtractedData idempotent), 3 controllers créés, 2 controllers nettoyés, 1 vue déplacée, 1 initializer ajouté (MIME type markdown), ~6 fichiers vues/specs migrés

## Constitution Check

| Principe | Statut | Notes |
|----------|--------|-------|
| I. Fullstack Rails — Hotwire Only | PASS | Pas de JS inline ajouté ; patterns Rails natifs |
| II. RGPD & Protection des mineurs | PASS | Exports d'identifiants préservent le modèle papier-seul |
| III. Security | PASS | Authorization via `current_user.subjects.find` / `current_user.classrooms.find` |
| IV. Testing | PASS | Tests d'idempotence ajoutés à PersistExtractedData, request specs pour nouveaux controllers |
| V. Performance & Simplicity | PASS | Service idempotent = défense en profondeur, pattern partagé |
| VI. Development Workflow | PASS | Plan validé, branche feature, PR + CI |

## Project Structure

```text
app/
├── controllers/
│   └── teacher/
│       ├── subjects_controller.rb                 # Retirer retry_extraction + assign
│       ├── subjects/
│       │   ├── extractions_controller.rb          # NEW
│       │   ├── assignments_controller.rb          # NEW
│       │   └── publications_controller.rb         # Mettre à jour redirect après publish!
│       ├── classrooms_controller.rb               # Retirer export_pdf + export_markdown
│       └── classrooms/
│           └── exports_controller.rb              # NEW
├── services/
│   └── persist_extracted_data.rb                  # Ajouter destroy_all idempotent
└── views/
    └── teacher/
        └── subjects/
            ├── assign.html.erb                    # DELETE (déplacée)
            └── assignments/
                └── edit.html.erb                  # NEW (ex-assign.html.erb)

config/
├── initializers/
│   └── mime_types.rb                              # NEW — Mime::Type.register "text/markdown", :markdown
└── routes.rb                                      # Retirer member actions, ajouter 3 resources

spec/
├── requests/
│   └── teacher/
│       ├── subjects/
│       │   ├── extractions_spec.rb                # NEW
│       │   └── assignments_spec.rb                # NEW
│       └── classrooms/
│           └── exports_spec.rb                    # NEW
├── services/
│   └── persist_extracted_data_spec.rb             # Ajouter spec d'idempotence
├── features/
│   ├── teacher_subject_upload_spec.rb             # Vérifier labels stables
│   ├── teacher_question_validation_spec.rb       # Ligne 147 à mettre à jour
│   └── teacher_classroom_management_spec.rb      # Ligne 162 à mettre à jour
└── requests/
    └── teacher/
        ├── subjects_spec.rb                       # Retirer tests retry_extraction + assign
        ├── classrooms_spec.rb                     # Retirer tests exports
        └── subjects/
            └── publications_spec.rb               # Mettre à jour assert redirect_to
```

## Implementation Phases

### Phase 1 — Service idempotent + MIME type

**Foundational — prérequis aux user stories**

1. Modifier `PersistExtractedData#call` : ajouter `@subject.parts.specific.destroy_all` avant la boucle de création des specific parts (dans la transaction)
2. Créer `config/initializers/mime_types.rb` avec `Mime::Type.register "text/markdown", :markdown`
3. Ajouter spec d'idempotence : `spec/services/persist_extracted_data_spec.rb` — vérifier que rappeler `.call` sur un subject avec specific parts existantes en supprime les anciennes et recrée les nouvelles (pas de doublons)

### Phase 2 — Routes

Mettre à jour `config/routes.rb` :

```ruby
resources :classrooms, only: [:index, :new, :create, :show] do
  resources :students, only: [:index, :new, :create], shallow: true do
    collection do
      get  :bulk_new
      post :bulk_create
    end
    resource :password_reset, only: [:create], module: "students"
  end
  resource :export, only: [:show], module: "classrooms"
  # SUPPRIMÉ: member do get :export_pdf; get :export_markdown; end
end

resources :subjects, only: [:index, :new, :create, :show] do
  resources :parts, only: [:show] do
    resources :questions, only: [:update, :destroy], shallow: true do
      resource :validation, only: [:create, :destroy], module: "questions"
    end
  end
  resource :publication, only: [:create, :destroy], module: "subjects"
  resource :extraction,  only: [:create], module: "subjects"
  resource :assignment,  only: [:edit, :update], module: "subjects"
  # SUPPRIMÉ: member do post :retry_extraction; get/patch :assign; end
end
```

### Phase 3 — Nouveau controller ExtractionsController

Voir research.md R4. Pattern simple : guard `failed?` → `update! + perform_later` ou redirect avec alert.

### Phase 4 — Nouveau controller AssignmentsController + déplacement vue

1. Créer controller (voir research.md R5)
2. `git mv app/views/teacher/subjects/assign.html.erb app/views/teacher/subjects/assignments/edit.html.erb`
3. Adapter le `form_with url:` dans la vue déplacée
4. Mettre à jour les 2 liens vers `edit_teacher_subject_assignment_path`

### Phase 5 — Nouveau controller ExportsController + respond_to

Voir research.md R3. Un controller, un `show` action, 2 blocs dans `respond_to`.

### Phase 6 — Migration des vues

| Fichier | Action |
|---------|--------|
| `app/views/teacher/subjects/show.html.erb:45` | `assign_teacher_subject_path` → `edit_teacher_subject_assignment_path` |
| `app/views/teacher/subjects/_stats.html.erb:45` | idem |
| `app/views/teacher/subjects/_extraction_status.html.erb:29` | `retry_extraction_teacher_subject_path` → `teacher_subject_extraction_path` (method: :post) |
| `app/views/teacher/classrooms/show.html.erb:69` | `export_pdf_teacher_classroom_path(c)` → `teacher_classroom_export_path(c, format: :pdf)` |
| `app/views/teacher/classrooms/show.html.erb:74` | `export_markdown_...` → `teacher_classroom_export_path(c, format: :markdown)` |

### Phase 7 — Mise à jour du redirect dans publications_controller (vague 1)

`app/controllers/teacher/subjects/publications_controller.rb` : la redirection après `create` pointe vers `assign_teacher_subject_path(@subject)` (URL supprimée). Remplacer par `edit_teacher_subject_assignment_path(@subject)`.

### Phase 8 — Suppression du code ancien

- `Teacher::SubjectsController` : retirer actions `retry_extraction`, `assign` + ajuster `before_action :set_subject, only:` (enlever ces symboles)
- `Teacher::ClassroomsController` : retirer actions `export_pdf`, `export_markdown` + ajuster `before_action :set_classroom, only:`

### Phase 9 — Tests

- **Nouveaux request specs** : 3 fichiers (extractions, assignments, exports)
- **Specs existants mis à jour** :
  - `spec/requests/teacher/subjects_spec.rb` : retirer ou commentaires pointant vers les nouveaux
  - `spec/requests/teacher/classrooms_spec.rb` : idem
  - `spec/requests/teacher/subjects/publications_spec.rb:27` : URL assert
  - `spec/features/teacher_question_validation_spec.rb:147` : visit URL
  - `spec/features/teacher_classroom_management_spec.rb:162` : href check
- **Feature specs** : vérifier que `teacher_subject_upload_spec.rb` (retry) et autres passent sans modification (labels stables)

### Phase 10 — Validation finale

- `bundle exec rspec` — tous tests passent (modulo flaky pré-existants)
- Grep : aucune occurrence de `retry_extraction_teacher_subject_path`, `assign_teacher_subject_path`, `export_pdf_teacher_classroom_path`, `export_markdown_teacher_classroom_path` dans `app/` et `spec/`
- Grep : aucune occurrence de `def retry_extraction`, `def assign`, `def export_pdf`, `def export_markdown` dans `Teacher::SubjectsController` et `Teacher::ClassroomsController`
- `bin/rubocop` → 0 offense

## Risques et mitigations

| Risque | Impact | Mitigation |
|--------|--------|-----------|
| `PersistExtractedData#call` destroy_all casse première extraction | Faible | `destroy_all` sur collection vide = no-op. Test dédié à ajouter. |
| MIME type markdown pas reconnu par le browser | Moyen | `disposition: "attachment"` force le download. Content-Type `text/markdown` est suffisant. |
| Redirect après publish pointe vers URL morte | Moyen | Phase 7 explicite cette mise à jour. |
| Vue `assign.html.erb` avait des specs visuelles spécifiques | Faible | Contenu préservé, seule l'URL change. |

## Scope Adjustments from Research

1. **Guard extraction** : pas de nouvelle exception `ExtractionJob::InvalidRetry` — pragmatique, logique directe dans le controller (voir R4)
2. **Cleanup idempotent au niveau service** : approche 2 choisie (PersistExtractedData), test dédié (voir R6)
3. **Format markdown** : MIME type enregistré dans initializer (voir R3)
4. **Publications controller redirect** : update nécessaire (vague 1 pointait vers `assign` qui disparaît) — phase 7 dédiée

## Complexity Tracking

Aucune violation de constitution. 2 patterns nouveaux introduits (edit/update + respond_to multi-format) — naturels Rails, pas de complexité ajoutée. Pattern d'idempotence au niveau service = défense en profondeur, améliore la qualité générale.
