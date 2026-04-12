# Quickstart: REST Doctrine Wave 3

## Contexte

Vague 3 de la migration REST. Patterns vagues 1-2 (PR #34, #35) validés.

## Ordre d'implémentation

1. **Phase 1** : PersistExtractedData idempotent + MIME type markdown (foundational)
2. **Phase 2** : Routes (retirer member actions, ajouter 3 resources)
3. **Phase 3** : ExtractionsController (guard + job enqueue)
4. **Phase 4** : AssignmentsController + déplacement vue `assign.html.erb` → `assignments/edit.html.erb`
5. **Phase 5** : ExportsController avec `respond_to` 2 formats
6. **Phase 6** : Migration des 5 vues (boutons/liens vers nouveaux helpers)
7. **Phase 7** : Mettre à jour le redirect dans publications_controller (pointait vers `assign`)
8. **Phase 8** : Nettoyage controllers anciens
9. **Phase 9** : Tests (3 request specs + mises à jour)
10. **Phase 10** : Validation finale + PR

## Fichiers de référence

- `specs/034-rest-extraction-assign-export/research.md` — 9 décisions
- `specs/034-rest-extraction-assign-export/plan.md` — détails par phase
- `~/.claude/skills/rails-conventions/references/rest-doctrine.md` — doctrine
- Pattern vague 1 : `app/controllers/teacher/subjects/publications_controller.rb`
- Pattern vague 2 shallow : `app/controllers/teacher/questions/validations_controller.rb`

## Points de vigilance

- **MIME type markdown** : enregistrer dans `config/initializers/mime_types.rb` avant d'écrire le controller Exports (sinon `format.markdown` ne sera pas reconnu)
- **Publications redirect** : la vague 1 redirige vers `assign_teacher_subject_path` après publish — URL qui disparaît. Ne pas oublier Phase 7.
- **PersistExtractedData** : le `destroy_all` doit être dans la transaction, avant la boucle de création
- **Vue assign.html.erb** : `git mv` plutôt que copy/delete pour préserver l'historique
