# Implementation Plan: Tuteur guidé — Micro-tâches de repérage

**Branch**: `011-guided-tutor-spotting` | **Date**: 2026-04-01 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/011-guided-tutor-spotting/spec.md`

## Summary

Ajouter un encart interactif "Avant de répondre" sur chaque question en mode tuteur. L'encart demande à l'élève d'identifier le type de tâche (radio) et les sources de données (checkboxes) avant de pouvoir voir la correction. Le feedback est immédiat et basé sur les données existantes en base (`answer_type`, `data_hints`). Le chat IA est enrichi avec le contexte du repérage.

## Technical Context

**Language/Version**: Ruby 3.3+ / Rails 8.1.3
**Primary Dependencies**: Hotwire (Turbo Streams, Stimulus), ViewComponent, Sidekiq, ActionCable
**Storage**: PostgreSQL via Neon (JSONB pour l'état du tuteur)
**Testing**: RSpec + FactoryBot + Capybara (CI via GitHub Actions)
**Target Platform**: Web (desktop + mobile responsive)
**Project Type**: Web application fullstack Rails
**Performance Goals**: Feedback de repérage instantané (pas d'appel IA, données en base)
**Constraints**: Constitution TDD obligatoire, RGPD mineurs, code anglais / UI français

## Constitution Check

| Principle | Status | Notes |
|---|---|---|
| I. Fullstack Rails — Hotwire Only | PASS | Turbo Frames + Stimulus, pas de SPA |
| II. RGPD & Protection mineurs | PASS | Pas de nouvelle donnée personnelle. État tuteur dans session existante |
| III. Security | PASS | Pas de clé API exposée. État dans JSONB server-side |
| IV. Test-First (NON-NEGOTIABLE) | PASS | TDD prévu : tests avant implémentation |
| V. Performance & Simplicity | PASS | Pas d'appel IA pour le repérage, données en base |

Aucune violation. Pas de complexité supplémentaire à justifier.

## Project Structure

### Documentation (this feature)

```text
specs/011-guided-tutor-spotting/
├── spec.md
├── plan.md              # This file
├── research.md          # Phase 0
├── data-model.md        # Phase 1
└── tasks.md             # Phase 2 (via /speckit.tasks)
```

### Source Code (repository root)

```text
app/
├── controllers/student/
│   └── tutor_controller.rb          # NEW: activate, verify_spotting, skip_spotting
├── models/
│   └── student_session.rb           # MODIFY: tutor_state helpers
├── services/
│   └── build_tutor_prompt.rb        # MODIFY: spotting context section
├── views/student/
│   ├── tutor/
│   │   ├── _spotting_card.html.erb  # NEW: encart radio + checkboxes
│   │   ├── _spotting_feedback.html.erb # NEW: résultat correct/incorrect
│   │   └── _tutor_banner.html.erb   # NEW: bannière activation
│   ├── subjects/
│   │   └── show.html.erb            # MODIFY: bannière conditionnelle
│   └── questions/
│       └── show.html.erb            # MODIFY: encart + correction conditionnelle
├── javascript/controllers/
│   ├── spotting_controller.js       # NEW: interaction radio/checkboxes
│   └── chat_controller.js           # MODIFY: openWithMessage()
├── components/                      # Réutilise BadgeComponent, ButtonComponent existants

config/
└── routes.rb                        # MODIFY: routes tutor

db/migrate/
└── XXX_add_tutor_state_to_student_sessions.rb  # NEW

spec/
├── models/student_session_spec.rb   # MODIFY: tutor_state helpers
├── controllers/student/tutor_controller_spec.rb  # NEW (request specs)
├── services/build_tutor_prompt_spec.rb  # MODIFY: spotting context
└── features/
    ├── student_spotting_spec.rb      # NEW: acceptance scenarios US1
    ├── student_tutor_activation_spec.rb  # NEW: US2
    └── student_tutor_chat_spec.rb    # NEW: US3
```

**Structure Decision**: Rails standard — controllers dans `student/`, partials dans `views/student/tutor/`, un Stimulus controller dédié. Pas de nouveau modèle, état stocké en JSONB dans `student_sessions`.
