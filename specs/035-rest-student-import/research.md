# Research: REST Doctrine Wave 4 — Student Import

**Date**: 2026-04-12 | **Branch**: `035-rest-student-import`

## R1 — Resource name: `:student_import` (singulier)

**Decision**: `resource :student_import, only: [:new, :create], module: "classrooms"`.

**Rationale**:
- Singular resource : 1 formulaire d'import par classe à un instant donné, pas de collection/historique
- `student_import` plus évocateur que `student_batch` — prépare un futur import CSV (post-MVP backlog)
- Controller `StudentImportsController` (pluriel conventionnel Rails)
- URLs `GET/POST /teacher/classrooms/:classroom_id/student_import[/new]`

**Alternatives** :
- `:student_batch` → plus technique, moins évocateur
- `:bulk_student_creation` → verbeux, pas idiomatique

## R2 — Logique métier préservée telle quelle

**Decision**: Le nouveau `Teacher::Classrooms::StudentImportsController#create` reprend **mot pour mot** la logique actuelle de `bulk_create` : split textarea ligne par ligne, `GenerateStudentCredentials.call`, stockage session, redirect.

**Rationale**: 
- Pas de bug connu dans la logique existante
- Pas de demande de nouvelle fonctionnalité
- Refactoring = repositionnement REST pur, pas changement comportemental

## R3 — Pas de nouveau pattern technique

**Decision**: Réutilisation stricte des patterns établis :
- Authorization via `current_user.classrooms.find(params[:classroom_id])` (pattern vagues 2-3)
- `before_action :set_classroom` simple
- Redirect HTML (pas de Turbo Stream — cohérent avec le comportement actuel qui redirige vers la page classroom)

## R4 — Déplacement de la vue

**Decision**: `git mv app/views/teacher/students/bulk_new.html.erb → app/views/teacher/classrooms/student_imports/new.html.erb`

**Adaptations dans la vue** :
- `form_with url: bulk_create_teacher_classroom_students_path(@classroom)` → `form_with url: teacher_classroom_student_import_path(@classroom)`
- Le `link_to` de retour vers classroom : inchangé

## R5 — Impact sur les fichiers existants (grep exhaustif)

| Fichier | Ligne | Action |
|---------|-------|--------|
| `app/views/teacher/classrooms/show.html.erb` | 64 | `bulk_new_teacher_classroom_students_path(@classroom)` → `new_teacher_classroom_student_import_path(@classroom)` |
| `app/views/teacher/students/bulk_new.html.erb` | 14 | Déplacer fichier + `form_with url:` mise à jour |
| `spec/requests/teacher/students_spec.rb` | 28 | `get bulk_new_teacher_classroom_students_path` → `get new_teacher_classroom_student_import_path` |
| `spec/requests/teacher/students_spec.rb` | 36 | `post bulk_create_teacher_classroom_students_path` → `post teacher_classroom_student_import_path` |
| `spec/features/teacher_classroom_management_spec.rb` | 116 | `click_link "Ajout en lot"` — inchangé (label stable) |

## R6 — Tests

**Decision**:
- Nouveau request spec : `spec/requests/teacher/classrooms/student_imports_spec.rb` avec 4-5 scenarios (GET new, POST happy path, POST ligne invalide, POST textarea vide, 404 non-owner)
- Spec existant `teacher/students_spec.rb` : retirer les tests `bulk_new`/`bulk_create` (remplacés par le nouveau spec) ou les adapter
- Feature spec `teacher_classroom_management_spec.rb` : passe sans modification (label "Ajout en lot" stable)

## Résumé

| Item | Décision |
|------|---------|
| Resource | `resource :student_import, only: [:new, :create]` |
| Controller | `Teacher::Classrooms::StudentImportsController` (module classrooms) |
| Logique métier | Copie intégrale depuis `bulk_create` |
| Vue | Déplacée avec 1 ligne modifiée (form URL) |
| Nouveaux patterns | Aucun |
| Refs à migrer | 4 fichiers (1 vue + 1 partial form + 1 link + 1 request spec avec 2 refs) |
