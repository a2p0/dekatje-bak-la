# Implementation Plan: Teacher P0 bug fixes

**Branch**: `041-teacher-p0-bugs` | **Date**: 2026-04-16 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/041-teacher-p0-bugs/spec.md`

## Summary

Trois correctifs ciblés côté enseignant, aucune refonte visuelle, scope α minimal.

1. **P0-a (US1)** — Exposer un bouton "Télécharger la fiche PDF" dans le bandeau d'identifiants générés sur la page de détail classe, pointant sur la route d'export PDF existante (`teacher_classroom_export_path(@classroom, format: :pdf)`). Pas de nouveau service, pas de nouvelle route. 1 seule modification de vue.
2. **P0-b (US2)** — Ajouter l'action `destroy` sur `Teacher::SubjectsController`, qui appelle `@subject.update!(discarded_at: Time.current)`. Route REST `DELETE /teacher/subjects/:id`. Bouton "Archiver" sur `teacher/subjects/show` (variant danger/ghost, avec `turbo_confirm`). Scope `kept` existe déjà dans le modèle et est déjà utilisé dans `SubjectsController#index`.
3. **P0-c (US3)** — Enrichir `teacher/subjects/_extraction_status.html.erb` : afficher `time_ago_in_words(job.updated_at)` quand `job.processing?`, ajouter `aria-live="polite"` sur `#extraction-status`. Pas de migration, pas de nouveau champ.

Impact : ~30 lignes de prod + tests RSpec/Capybara. 3 commits atomiques conformes Conventional Commits.

## Technical Context

**Language/Version** : Ruby 3.3+ / Rails 8.1
**Primary Dependencies** : aucune nouvelle. Réutilise `ButtonComponent`, `BadgeComponent`, `time_ago_in_words` helper Rails, scope `kept` existant sur `Subject`.
**Storage** : PostgreSQL via Neon. Colonne `subjects.discarded_at` déjà existante (scope `kept` confirmé dans `app/models/subject.rb:32`). Pas de migration.
**Testing** : RSpec 8 + FactoryBot + Capybara (feature specs) + Rails request specs (controller unit).
**Target Platform** : Rails server, navigateurs modernes (Turbo 8 pour `turbo_confirm`).
**Project Type** : Rails fullstack Hotwire (pas de frontend séparé).
**Performance Goals** : N/A (fix UI/UX, impact négligeable sur perfs).
**Constraints** : aucune refonte visuelle (périmètre 027 séparé). Une concern = un commit. Tests E2E via CI (constitution IV — locale trop lente).
**Scale/Scope** : 3 stories indépendantes. ~30 lignes prod + ~80 lignes tests. 3 fichiers de vue + 1 controller + 1 route + 3 specs.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Évaluation vs `.specify/memory/constitution.md` v2.0.0 :

| Principe | Statut | Note |
|---|---|---|
| I. Fullstack Rails — Hotwire Only | ✅ | Pas de JS custom, uses Turbo + Stimulus existants. |
| II. RGPD & Protection mineurs | ✅ | Aucune collecte nouvelle. P0-a améliore la protection (évite perte credentials → évite reset massif = réduit risque de mots de passe recyclés). |
| III. Security | ✅ | Scope `owner` conservé sur destroy (`current_teacher.subjects.find`). Pas de nouveau secret. Pas de log de credentials. |
| IV. Testing (NON-NEGOTIABLE) | ✅ | Feature specs Capybara pour chaque US + request spec controller pour destroy. TDD respecté. |
| V. Performance & Simplicity | ✅ | ~30 lignes prod. Pas d'optim, lisibilité prioritaire. |
| VI. Development Workflow | ✅ | Branche `041-teacher-p0-bugs` créée, plan validé par user, 3 commits atomiques (un concern par commit), PR systématique avant merge. |

**Verdict** : **GATE PASSED**. Aucune complexité à justifier.

## Project Structure

### Documentation (this feature)

```text
specs/041-teacher-p0-bugs/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
│   └── routes.md        # REST contract for DELETE /teacher/subjects/:id
└── tasks.md             # Phase 2 output (/speckit.tasks — not created here)
```

### Source Code (repository root)

Le projet est un monolithe Rails 8 fullstack. Structure standard Rails — pas de backend/frontend séparés.

```text
app/
├── controllers/
│   └── teacher/
│       └── subjects_controller.rb          # US2: ajouter #destroy
├── models/
│   └── subject.rb                           # US2: scope kept existe déjà (aucune modif)
├── views/
│   └── teacher/
│       ├── classrooms/
│       │   └── show.html.erb                # US1: bouton "Télécharger PDF" dans bandeau credentials
│       └── subjects/
│           ├── show.html.erb                # US2: bouton "Archiver"
│           └── _extraction_status.html.erb  # US3: time_ago_in_words + aria-live

config/
└── routes.rb                                # US2: ajouter :destroy à resources :subjects

spec/
├── features/
│   └── teacher/
│       ├── classroom_credentials_download_spec.rb   # US1
│       ├── subject_archive_spec.rb                   # US2
│       └── extraction_status_feedback_spec.rb        # US3
└── requests/
    └── teacher/
        └── subjects_controller_spec.rb               # US2 controller
```

**Structure Decision** : Rails monolith existant. Tous les fichiers touchés vivent dans `app/controllers/teacher/`, `app/views/teacher/`, `config/routes.rb`, `spec/features/teacher/`, `spec/requests/teacher/`. Aucun nouveau service, aucun nouveau composant, aucun nouveau job.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

N/A — aucune violation de constitution, pas de complexité à justifier.
