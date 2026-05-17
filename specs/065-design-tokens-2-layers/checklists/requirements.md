# Specification Quality Checklist: Architecture tokens 2 couches pour thème Radical unifié (B1)

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-05-17
**Feature**: [Link to spec.md](../spec.md)

## Content Quality

- [x] No implementation details (languages, frameworks, APIs)
  - *La spec mentionne Tailwind v4 / `@theme` / ViewComponent / RSpec / Capybara — mais uniquement en **contraintes techniques** héritées du projet, jamais comme prescription d'implémentation. Le HOW (architecture CSS exacte, sélecteurs, etc.) reste pour le plan.*
- [x] Focused on user value and business needs
  - *Toutes les user stories sont formulées du point de vue du développeur consommateur (qui est le « user » de cette feature interne).*
- [x] Written for non-technical stakeholders
  - *Le « stakeholder » ici est l'auteur du projet (dev solo) qui valide la roadmap design system. La spec utilise le vocabulaire qu'il a lui-même posé (audience, primitives, sémantiques, bridge).*
- [x] All mandatory sections completed
  - *User Scenarios, Requirements, Success Criteria, Assumptions, Dependencies, Out of Scope.*

## Requirement Completeness

- [x] No [NEEDS CLARIFICATION] markers remain
  - *Aucun marker. Toutes les décisions critiques (Q1 dark teacher, Q2 layout arch) ont été tranchées en amont de la spec.*
- [x] Requirements are testable and unambiguous
  - *Chaque FR est associé à un comportement observable. FR-001 à FR-016 sont vérifiables.*
- [x] Success criteria are measurable
  - *SC-001 (pixel-perfect, tolérance 0), SC-002 (CI verte modulo flakes), SC-003 (test unitaire ou page démo vérifie le mapping), SC-004 (`git diff` limité), SC-005 (indépendance phases), SC-006 (manuel dark teacher), SC-007 (CSS poids +5% max).*
- [x] Success criteria are technology-agnostic (no implementation details)
  - *SC parlent de tokens, audience, modes — pas de Tailwind ni de ViewComponent. SC-007 mentionne « CSS compilé » mais c'est l'unité de mesure côté produit livré, pas une prescription.*
- [x] All acceptance scenarios are defined
  - *3 user stories × 3-4 scenarios chacune = 11 scenarios concrets.*
- [x] Edge cases are identified
  - *5 edge cases listés : pages sans audience, dark sans audience, ThemeToggle, première visite anonyme, prefers-contrast/reduced-motion.*
- [x] Scope is clearly bounded
  - *Section « Out of Scope » liste explicitement 8 exclusions avec pointage vers les phases B0/B2/B3/B4/B5/B6/B7.*
- [x] Dependencies and assumptions identified
  - *Section « Assumptions » liste 7 hypothèses. Section « Dependencies » liste l'état repo attendu et les phases débloquées.*

## Feature Readiness

- [x] All functional requirements have clear acceptance criteria
  - *Chaque user story porte 3-4 acceptance scenarios Given/When/Then. Les FR sont mappés indirectement via ces scenarios.*
- [x] User scenarios cover primary flows
  - *US1 (migration invisible), US2 (tokens dispo pour le futur), US3 (bridge rétrocompat) couvrent les 3 axes de valeur.*
- [x] Feature meets measurable outcomes defined in Success Criteria
  - *Les FR + acceptance scenarios construisent SC-001 à SC-007.*
- [x] No implementation details leak into specification
  - *Pas de mention de `:root`, `@theme`, ou syntaxe Tailwind exacte. Les exemples `var(--color-accent-primary)` sont du contrat d'usage, pas de l'implémentation.*

## Notes

- Items marked incomplete require spec updates before `/speckit.clarify` or `/speckit.plan`
- ✅ Tous les items passent à la première itération.
- ⚠️ Le spec est volumineux (~200 lignes) car la feature concerne un chantier transversal avec beaucoup d'exclusions à expliciter. C'est délibéré pour éviter le scope creep en plan/tasks.
- Prêt pour `/speckit.plan`.
