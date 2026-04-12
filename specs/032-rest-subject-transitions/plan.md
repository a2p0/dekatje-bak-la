# Implementation Plan: REST Doctrine — Subject Publication

**Branch**: `032-rest-subject-transitions` | **Date**: 2026-04-12 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/032-rest-subject-transitions/spec.md`

## Summary

Migrer les actions `publish` / `unpublish` de `Teacher::SubjectsController` vers un nouveau controller RESTful `Teacher::Subjects::PublicationsController`. Nettoyer la route `archive` orpheline. Introduire une méthode métier `Subject#publish!`/`#unpublish!` avec exception `Subject::InvalidTransition`.

Première vague de la migration doctrine CRUD-only (5 vagues prévues — voir `docs/rest-doctrine-migration/README.md`).

## Technical Context

**Language/Version**: Ruby 3.3+ / Rails 8.1  
**Primary Dependencies**: Hotwire (Turbo Streams), Devise (authorization existante)  
**Storage**: PostgreSQL via Neon  
**Testing**: RSpec + FactoryBot + Capybara  
**Target Platform**: Linux server (Coolify/Nixpacks)  
**Project Type**: Web application fullstack Rails  
**Performance Goals**: N/A (refactoring, pas de nouvelles fonctionnalités)  
**Constraints**: CI GitHub Actions comme runner de tests autoritaire  
**Scale/Scope**: 1 modèle modifié, 2 controllers (ancien nettoyé + nouveau créé), 2 vues modifiées, 1 feature spec à vérifier, 1 request spec à créer

## Constitution Check

| Principe | Statut | Notes |
|----------|--------|-------|
| I. Fullstack Rails — Hotwire Only | PASS | Turbo Streams pour les transitions |
| II. RGPD & Protection des mineurs | PASS | Aucun changement de données |
| III. Security | PASS | Autorisation préservée via scope `current_user.subjects.find` |
| IV. Testing | PASS | Feature specs existants + nouveau request spec |
| V. Performance & Simplicity | PASS | Code plus simple : 2 actions au lieu de 3 + 1 route morte supprimée |
| VI. Development Workflow | PASS | Plan validé. Branche feature. PR + CI. |

## Project Structure

### Documentation (this feature)

```text
specs/032-rest-subject-transitions/
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
│       ├── subjects_controller.rb               # Retirer publish/unpublish/archive
│       └── subjects/
│           └── publications_controller.rb       # NEW
├── models/
│   └── subject.rb                               # Ajouter InvalidTransition + publish!/unpublish!
└── views/
    ├── teacher/
    │   ├── subjects/
    │   │   ├── _stats.html.erb                 # Mettre à jour les 2 button_to
    │   │   └── publications/                    # NEW dir
    │   │       ├── create.turbo_stream.erb      # NEW
    │   │       └── destroy.turbo_stream.erb     # NEW
    │   └── parts/
    │       └── show.html.erb                    # Mettre à jour 1 button_to

config/
└── routes.rb                                    # Supprimer member publish/archive/unpublish, ajouter resource :publication

spec/
├── features/
│   └── teacher_question_validation_spec.rb     # Vérifier que les specs passent (labels identiques)
├── models/
│   └── subject_spec.rb                         # Ajouter specs pour publish!/unpublish!
└── requests/
    └── teacher/
        └── subjects/
            └── publications_spec.rb            # NEW
```

## Implementation Phases

### Phase 1 — Modèle : méthodes métier et exception (Commit 1)

**Scope**: Ajouter `Subject::InvalidTransition`, `Subject#publish!`, `Subject#unpublish!`.

**Approche**:

```ruby
class Subject < ApplicationRecord
  class InvalidTransition < StandardError; end

  # ... existing code ...

  def publish!
    raise InvalidTransition, "Le sujet est déjà publié." if published?
    raise InvalidTransition, "Publiez au moins une question validée avant de publier." unless publishable?
    update!(status: :published)
  end

  def unpublish!
    raise InvalidTransition, "Seul un sujet publié peut être dépublié." unless published?
    update!(status: :draft)
  end
end
```

**Tests** : ajouter à `spec/models/subject_spec.rb` (ou créer si inexistant) :
- `publish!` happy path, déjà publié, pas publishable
- `unpublish!` happy path, pas publié

### Phase 2 — Nouveau controller et routes (Commit 2)

**Scope**: Créer `Teacher::Subjects::PublicationsController`. Mettre à jour routes.

**Approche**:

```ruby
# app/controllers/teacher/subjects/publications_controller.rb
class Teacher::Subjects::PublicationsController < Teacher::BaseController
  before_action :set_subject
  rescue_from Subject::InvalidTransition, with: :invalid_transition

  def create
    @subject.publish!
    respond_to do |format|
      format.html        { redirect_to assign_teacher_subject_path(@subject), notice: "Sujet publié. Assignez-le maintenant aux classes." }
      format.turbo_stream
    end
  end

  def destroy
    @subject.unpublish!
    respond_to do |format|
      format.html        { redirect_to teacher_subject_path(@subject), notice: "Sujet dépublié." }
      format.turbo_stream
    end
  end

  private

  def set_subject
    @subject = current_user.subjects.find(params[:subject_id])
  end

  def invalid_transition(exception)
    redirect_to teacher_subject_path(@subject), alert: exception.message
  end
end
```

**Routes** (dans `namespace :teacher` existant) :

```ruby
resources :subjects, only: [:index, :new, :create, :show] do
  member do
    post :retry_extraction
    get  :assign
    patch :assign
    # SUPPRIMÉ: patch :publish, patch :archive, patch :unpublish
  end
  resource :publication, only: [:create, :destroy], module: "subjects"
end
```

### Phase 3 — Turbo Stream views (Commit 3)

**Scope**: Créer les 2 vues Turbo Stream.

`app/views/teacher/subjects/publications/create.turbo_stream.erb` :
```erb
<%= turbo_stream.replace "subject_stats_#{@subject.id}",
      partial: "teacher/subjects/stats", locals: { subject: @subject } %>
<%= turbo_stream.replace "flash", partial: "shared/flash", locals: { notice: "Sujet publié." } %>
```

`destroy.turbo_stream.erb` : idem avec locals `notice: "Sujet dépublié."`.

Vérifier que le partial `_stats` a un wrapper avec `id="subject_stats_#{subject.id}"`. Si non, l'ajouter.

### Phase 4 — Migration des boutons dans les vues (Commit 4)

**Scope**: Remplacer les 3 `button_to` qui pointent vers les anciens helpers.

**Fichiers** :
- `app/views/teacher/subjects/_stats.html.erb:25-29` — bouton "Publier le sujet"
- `app/views/teacher/subjects/_stats.html.erb:40-44` — bouton "Dépublier"
- `app/views/teacher/parts/show.html.erb:62-66` — bouton "Publier le sujet" (redondant)

**Transformation** :
```erb
# Avant
<%= button_to "Publier le sujet", publish_teacher_subject_path(subject), method: :patch, ... %>
<%= button_to "Dépublier", unpublish_teacher_subject_path(subject), method: :patch, ... %>

# Après
<%= button_to "Publier le sujet", teacher_subject_publication_path(subject), method: :post, ... %>
<%= button_to "Dépublier", teacher_subject_publication_path(subject), method: :delete, ... %>
```

### Phase 5 — Suppression du code ancien (Commit 5)

**Scope**: Retirer les méthodes `publish`, `unpublish`, `archive` de `Teacher::SubjectsController`. Vérifier que le `before_action :set_subject` pointant sur ces actions est nettoyé.

**Approche** : après Phase 4, les anciennes actions ne sont plus appelées. On peut donc les supprimer sans casser le code.

Attention au `before_action` qui restreint `set_subject` aux actions concernées. Vérifier et ajuster.

### Phase 6 — Tests (Commit 6)

**Scope**: Créer le request spec, vérifier que les feature specs existants passent.

**Nouveau fichier** `spec/requests/teacher/subjects/publications_spec.rb` :
- POST happy path (sujet pending_validation + question validée)
- POST sujet déjà publié → redirect + alert
- POST sans question validée → redirect + alert
- DELETE happy path (sujet published)
- DELETE sujet draft → redirect + alert
- Non-propriétaire → 404

**Feature spec existant** : `teacher_question_validation_spec.rb` doit passer sans modification (les tests utilisent les labels de boutons "Publier le sujet" / "Dépublier", pas les helpers).

## Risques et mitigations

| Risque | Impact | Mitigation |
|--------|--------|-----------|
| Partial `_stats` sans ID wrapper | Moyen | Vérifier avant Phase 3 et l'ajouter si nécessaire |
| Feature specs cassent (labels différents) | Faible | Labels préservés ("Publier le sujet", "Dépublier") |
| Archive route orpheline avait un caller manqué | Faible | Grep déjà fait dans research.md — confirmé zéro caller |
| Bug latent du double-publish devient visible | Faible | Nouvelle règle métier = comportement correct, user-friendly |

## Scope Adjustments from Research

1. **Archive retirée du scope** (R2) — route orpheline sans vue, on la supprime au passage
2. **Unpublish cible `:draft`** (R1) — comportement actuel préservé, pas `:pending_validation`
3. **Nouvelle règle** : `publish!` refuse les déjà-publiés (R3) — fixe bug latent

## Complexity Tracking

Aucune violation de constitution. Nouveau pattern `Model#transition!` + `rescue_from` devient la référence pour les 4 vagues suivantes.
