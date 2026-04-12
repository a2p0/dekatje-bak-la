# Quickstart: REST Doctrine Wave 2

## Contexte

Vague 2 de la migration REST. Pattern validé en vague 1 (PR #34).

## Ordre d'implémentation

1. **Phase 1** : Question model — `validate!`/`invalidate!` + `InvalidTransition`
2. **Phase 2** : Routes — shallow nesting + resources `:validation` et `:password_reset`
3. **Phase 3** : ValidationsController (Turbo Stream only)
4. **Phase 4** : PasswordResetsController (HTML redirect)
5. **Phase 5** : Migration des vues (3 fichiers, ~5 button_to + 1 form_with)
6. **Phase 6** : Nettoyage controllers anciens (actions + before_actions + scoping adapté pour update/destroy shallow)
7. **Phase 7** : Tests (model + 2 request specs)
8. **Phase 8** : Validation suite complète + PR

## Fichiers de référence

- `specs/033-rest-validation-password/research.md` — 9 décisions
- `specs/033-rest-validation-password/plan.md` — détails par phase
- `~/.claude/skills/rails-conventions/references/rest-doctrine.md` — doctrine
- `docs/rest-doctrine-migration/README.md` — plan global
- Pattern vague 1 : `app/controllers/teacher/subjects/publications_controller.rb` (référence)

## Points de vigilance

- **Shallow routing** affecte aussi `update`/`destroy` des questions (signature de `set_question` à adapter)
- **`parts`** devra aussi accepter `shallow: true` pour que la cascade fonctionne — vérifier la syntaxe Rails
- **Turbo Stream only** pour ValidationsController (l'usage actuel n'a pas de HTML fallback)
