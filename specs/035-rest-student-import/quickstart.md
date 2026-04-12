# Quickstart: REST Doctrine Wave 4 — Student Import

## Contexte

Vague 4 de la migration REST. **Simple** : pas de nouveau pattern, logique métier préservée.

## Ordre d'implémentation (7 phases courtes)

1. **Phase 1** : Routes (retirer collection bulk_*, ajouter resource student_import)
2. **Phase 2** : StudentImportsController (copie de la logique actuelle)
3. **Phase 3** : `git mv` de la vue + adapter form_with URL
4. **Phase 4** : Bouton "Ajout en lot" dans classrooms/show.html.erb
5. **Phase 5** : Supprimer bulk_new/bulk_create de StudentsController
6. **Phase 6** : Tests (nouveau request spec + cleanup de l'ancien)
7. **Phase 7** : Validation + PR

## Fichiers de référence

- `specs/035-rest-student-import/research.md` — décisions (simples)
- `specs/035-rest-student-import/plan.md` — détails par phase
- Pattern vague 3 : `app/controllers/teacher/classrooms/exports_controller.rb` (même module namespace)

## Estimation

Vague la plus courte : ~30 min d'implémentation + CI.
