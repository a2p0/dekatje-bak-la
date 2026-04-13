# Quickstart: REST Doctrine Wave 5a — Student Actions

## Contexte

Vague 5a. Pattern validé 4 fois (vagues 1-4). Scope student avec access_code préservé.

## Ordre d'implémentation (7 phases)

1. **Phase 1** : Routes (6 suppressions + 6 nouvelles resources avec `controller:` explicite)
2. **Phase 2** : 6 nouveaux controllers (héritent de Student::BaseController)
3. **Phase 3** : Migration des 10 occurrences dans 5 fichiers de vues
4. **Phase 4** : 1 ligne JS modifiée (test_key URL)
5. **Phase 5** : Nettoyage (4 controllers : SubjectsController, QuestionsController, SettingsController, TutorController)
6. **Phase 6** : 6 nouveaux request specs + vérification feature specs existants
7. **Phase 7** : Validation (grep, rubocop, suite complète)

## Fichiers de référence

- `specs/036-rest-student-actions/research.md` — 11 décisions
- `specs/036-rest-student-actions/plan.md` — détails par phase
- Pattern vague 3 pour singular resource : `app/controllers/teacher/subjects/publications_controller.rb`
- Pattern vague 4 pour controller nested : `app/controllers/teacher/classrooms/student_imports_controller.rb`
- Routes student existantes : `scope "/:access_code", as: :student` dans `config/routes.rb`

## Points de vigilance

- **settings_controller.js** : l'URL fetch est construite en JS, doit être mise à jour manuellement (ligne 47)
- **complete_part** : logique de redirection complexe (30+ lignes), copier verbatim
- **ScopeSelection** : `update` et non `create` (modification d'une propriété existante)
- **TutorActivation** : idempotent (guard `unless tutored?` préservé)
