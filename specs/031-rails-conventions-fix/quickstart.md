# Quickstart: Rails Conventions Audit Fix

## Contexte

Refactoring pur pour aligner le code sur les conventions Rails identifiées par l'audit `/rails-conventions audit`. Aucune fonctionnalité ajoutée, aucune migration.

## Pré-requis

- Ruby 3.3+, Rails 8.1 installés
- PostgreSQL (Neon) accessible via `DATABASE_URL`
- `bundle install` à jour

## Vérification rapide

```bash
# Vérifier que la suite de tests passe avant de commencer
bundle exec rspec
```

## Ordre d'implémentation

Les 8 commits sont indépendants mais ordonnés pour minimiser les conflits :

1. **Views form_with** — migrations mécaniques, aucune dépendance
2. **Views scripts** — créer le Stimulus controller access-code
3. **Views logique** — dépend des scopes (Phase 5) et méthodes modèle (Phase 6), mais peut être fait avant en pré-calculant dans le controller
4. **Jobs** — indépendant
5. **Scopes** — créer les scopes puis les utiliser dans les controllers
6. **Models N+1** — mémoisation et eager loading
7. **Services self.call** — refactoring mécanique, ne change pas les callers
8. **Services return values** — DOIT être fait après Phase 7 car on change l'interface

## Fichiers clés à consulter

- `specs/031-rails-conventions-fix/research.md` — décisions et justifications
- `specs/031-rails-conventions-fix/plan.md` — plan détaillé par phase
- `.specify/memory/constitution.md` — principes à respecter
