# Quickstart: REST Doctrine — Subject Publication

## Contexte

Refactoring RESTful des transitions d'état Subject. Première vague de la migration doctrine (voir `docs/rest-doctrine-migration/README.md`).

## Pré-requis

- Ruby 3.3+, Rails 8.1
- Suite de tests à jour : `bundle exec rspec` passe sur main (avec 1 failure flaky documentée)

## Vérification rapide

```bash
# Avant de commencer, vérifier l'état des tests concernés
bundle exec rspec spec/features/teacher_question_validation_spec.rb
bundle exec rspec spec/models/subject_spec.rb  # si existe
```

## Ordre d'implémentation

6 phases séquentielles (dépendances entre elles) :

1. **Phase 1** — Modèle : `Subject#publish!/unpublish!` + exception
2. **Phase 2** — Controller + routes (ancien ET nouveau coexistent)
3. **Phase 3** — Turbo Stream views
4. **Phase 4** — Migration des boutons (utilisent le nouveau controller)
5. **Phase 5** — Suppression du code ancien (actions `publish`/`unpublish`/`archive`)
6. **Phase 6** — Tests (request spec + vérification feature specs)

**Note importante** : entre Phase 2 et Phase 5, l'ancien code et le nouveau coexistent. C'est intentionnel — permet de migrer progressivement sans casser la navigation.

## Fichiers clés à consulter

- `specs/032-rest-subject-transitions/research.md` — décisions techniques (R1-R9)
- `specs/032-rest-subject-transitions/plan.md` — plan détaillé par phase
- `~/.claude/skills/rails-conventions/references/rest-doctrine.md` — doctrine de référence
- `docs/rest-doctrine-migration/README.md` — vue d'ensemble des 5 vagues
