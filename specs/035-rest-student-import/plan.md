# Implementation Plan: REST Doctrine Wave 4 — Student Import

**Branch**: `035-rest-student-import` | **Date**: 2026-04-12 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/035-rest-student-import/spec.md`

## Summary

Migrer 2 actions custom vers un controller RESTful :
- `Teacher::StudentsController#bulk_new` (GET) → `Teacher::Classrooms::StudentImportsController#new`
- `Teacher::StudentsController#bulk_create` (POST) → `Teacher::Classrooms::StudentImportsController#create`

Vague 4/5 de la migration REST doctrine. **Simple** : pas de bug fix, pas de nouveau pattern, logique métier préservée à l'identique.

## Technical Context

**Language/Version**: Ruby 3.3+ / Rails 8.1  
**Primary Dependencies**: Hotwire, Devise, existant `GenerateStudentCredentials` service  
**Storage**: PostgreSQL via Neon  
**Testing**: RSpec + FactoryBot + Capybara  
**Target Platform**: Linux server (Coolify/Nixpacks)  
**Project Type**: Web application fullstack Rails  
**Performance Goals**: Import 30 élèves en < 5s (SC-005)  
**Constraints**: CI GitHub Actions ; patterns vagues 1-3 comme référence  
**Scale/Scope**: 1 controller nouveau + 1 nettoyé, 1 vue déplacée, 2 routes repositionnées, ~5 fichiers touchés

## Constitution Check

| Principe | Statut | Notes |
|----------|--------|-------|
| I. Fullstack Rails — Hotwire Only | PASS | Redirect HTML standard (pas de JS inline) |
| II. RGPD & Protection des mineurs | PASS | Pas de changement, identifiants générés/stockés comme avant |
| III. Security | PASS | Authorization via `current_user.classrooms.find` |
| IV. Testing | PASS | Request spec nouveau + feature spec existant |
| V. Performance & Simplicity | PASS | Code plus simple : responsabilité séparée dans un controller dédié |
| VI. Development Workflow | PASS | Plan validé, branche feature, PR + CI |

## Project Structure

```text
app/
├── controllers/
│   └── teacher/
│       ├── students_controller.rb             # Retirer bulk_new + bulk_create
│       └── classrooms/
│           └── student_imports_controller.rb  # NEW
└── views/
    └── teacher/
        ├── students/
        │   └── bulk_new.html.erb              # DELETE (déplacée)
        └── classrooms/
            └── student_imports/
                └── new.html.erb               # NEW (ex-bulk_new.html.erb)

config/routes.rb                                # Retirer collection bulk_*, ajouter resource :student_import

spec/
└── requests/
    └── teacher/
        ├── students_spec.rb                   # Retirer tests bulk_new/bulk_create
        └── classrooms/
            └── student_imports_spec.rb        # NEW
```

## Implementation Phases

### Phase 1 — Routes

Retirer le bloc `collection do get :bulk_new; post :bulk_create; end` du `resources :students` dans `config/routes.rb`. Ajouter `resource :student_import, only: [:new, :create], module: "classrooms"` à l'intérieur du bloc `resources :classrooms`.

### Phase 2 — Nouveau controller

Créer `app/controllers/teacher/classrooms/student_imports_controller.rb` :

```ruby
class Teacher::Classrooms::StudentImportsController < Teacher::BaseController
  before_action :set_classroom

  def new
  end

  def create
    lines = params[:students_list].to_s.split("\n").map(&:strip).reject(&:empty?)
    generated = []
    errors = []

    lines.each do |line|
      parts = line.split(" ", 2)
      if parts.length < 2
        errors << "Ligne ignorée (format invalide) : #{line}"
        next
      end

      first_name, last_name = parts[0], parts[1]
      credentials = GenerateStudentCredentials.call(
        first_name: first_name, last_name: last_name, classroom: @classroom
      )

      student = @classroom.students.build(
        first_name: first_name, last_name: last_name,
        username: credentials.username, password: credentials.password
      )

      if student.save
        generated << { "name" => "#{first_name} #{last_name}",
                       "username" => credentials.username,
                       "password" => credentials.password }
      else
        errors << "Erreur pour #{line} : #{student.errors.full_messages.join(", ")}"
      end
    end

    session[:generated_credentials] = generated if generated.any?

    if errors.any?
      flash[:alert] = errors.join(" | ")
    else
      flash[:notice] = "#{generated.count} élèves ajoutés. Notez les identifiants ci-dessous."
    end

    redirect_to teacher_classroom_path(@classroom)
  end

  private

  def set_classroom
    @classroom = current_user.classrooms.find(params[:classroom_id])
  end
end
```

Logique copiée-collée depuis l'ancien `bulk_create` (R2), autorisation adaptée au pattern vagues 2-3.

### Phase 3 — Déplacement + adaptation de la vue

`git mv app/views/teacher/students/bulk_new.html.erb app/views/teacher/classrooms/student_imports/new.html.erb`

Dans la vue déplacée, remplacer `form_with url: bulk_create_teacher_classroom_students_path(@classroom), method: :post` par `form_with url: teacher_classroom_student_import_path(@classroom), method: :post`.

### Phase 4 — Migration du bouton

`app/views/teacher/classrooms/show.html.erb:64` : remplacer `href: bulk_new_teacher_classroom_students_path(@classroom)` par `href: new_teacher_classroom_student_import_path(@classroom)`.

### Phase 5 — Nettoyage ancien controller

Supprimer `bulk_new` et `bulk_create` de `Teacher::StudentsController`. Le `before_action :set_classroom` reste (utilisé par `new` et `create`).

### Phase 6 — Tests

1. Créer `spec/requests/teacher/classrooms/student_imports_spec.rb` avec :
   - GET new happy path (200, render)
   - POST happy path (textarea valide, élèves créés, redirect vers classroom, credentials en session)
   - POST ligne invalide (flash alert, autres lignes traitées)
   - POST textarea vide (redirect vers classroom, zéro élève créé, pas d'erreur)
   - GET new + POST : 404 pour classroom non-owner

2. Mettre à jour `spec/requests/teacher/students_spec.rb` : retirer les 2 describes `bulk_new` et `bulk_create` (remplacés par le nouveau spec). Ajouter commentaire pointant vers le nouveau fichier.

3. Lancer `bundle exec rspec spec/features/teacher_classroom_management_spec.rb` — doit passer (label "Ajout en lot" stable).

### Phase 7 — Validation finale

- `bundle exec rspec` — 0 régression (modulo flakys pré-existants)
- Grep : aucune occurrence de `bulk_new_teacher_classroom_students_path`, `bulk_create_teacher_classroom_students_path`, `def bulk_new`, `def bulk_create`
- `bin/rubocop` → 0 offense

## Risques et mitigations

| Risque | Impact | Mitigation |
|--------|--------|-----------|
| `teacher_classroom_student_import_path` vs `new_teacher_classroom_student_import_path` : confusion | Faible | Rails convention : `new_X_path` pour `GET X/new`, `X_path` pour `POST X` |
| Logique de parsing cassée au déplacement | Faible | Copie intégrale, tests couvrent les cas |
| Feature spec cassé si label change | Faible | Label "Ajout en lot" préservé, pas de raison de le changer |

## Scope Adjustments from Research

Aucun. Cette vague est simple et linéaire.

## Complexity Tracking

Aucune violation de constitution. Pas de nouveau pattern. Refactoring pur.
