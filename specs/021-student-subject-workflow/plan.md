# Implementation Plan: Workflow sujet complet élève

**Branch**: `021-student-subject-workflow` | **Date**: 2026-04-08 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/021-student-subject-workflow/spec.md`

## Summary

Refonte du parcours élève pour un sujet complet (parties communes + spécifiques). Le workflow actuel affiche toutes les parties en liste plate avec un bouton "Retour aux sujets" en fin de parcours. Le nouveau workflow introduit : regroupement visuel des parties par section_type avec objectifs, transitions "Fin de la partie" entre sections, mise en situation spécifique entre les deux parties, page récapitulative des questions non répondues, page de félicitations, et marqueurs visuels de progression sur les parties terminées.

Aucune migration nécessaire — le suivi des parties parcourues est stocké dans le JSONB `progression` existant du `StudentSession`.

## Technical Context

**Language/Version**: Ruby 3.3+ / Rails 8.1
**Primary Dependencies**: Hotwire (Turbo Streams, Stimulus), ViewComponent, Tailwind CSS
**Storage**: PostgreSQL via Neon (JSONB `progression` dans `student_sessions`)
**Testing**: RSpec + FactoryBot + Capybara (CI: GitHub Actions)
**Target Platform**: Web (Chrome, Firefox)
**Project Type**: Web application (fullstack Rails)
**Performance Goals**: N/A (MVP)
**Constraints**: Pas de nouvelle migration. Interface en français, code en anglais.
**Scale/Scope**: ~3 vues modifiées, ~2 nouvelles vues/partials, ~1 nouvelle action controller, ~6 méthodes modèle

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Fullstack Rails — Hotwire Only | ✅ | Pas de SPA, tout en Rails + Turbo |
| II. RGPD & Protection des mineurs | ✅ | Pas de collecte de données supplémentaires |
| III. Security | ✅ | Pas de nouvelles clés API ou secrets |
| IV. Testing | ✅ | Feature specs Capybara + unit specs RSpec prévus |
| V. Performance & Simplicity | ✅ | Code simple, pas d'optimisation prématurée |
| VI. Development Workflow | ✅ | Plan validé avant code, feature branch, PR systématique |

**Gate result: PASS**

## Project Structure

### Documentation (this feature)

```text
specs/021-student-subject-workflow/
├── plan.md              # This file
├── spec.md              # Feature specification
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── checklists/
│   └── requirements.md  # Quality checklist
└── tasks.md             # Phase 2 output (via /speckit.tasks)
```

### Source Code (files to modify/create)

```text
app/
├── controllers/
│   └── student/
│       ├── subjects_controller.rb      # MODIFY: show logic (workflow routing), new complete_part action
│       └── questions_controller.rb     # MODIFY: navigation logic (Fin de la partie, review redirect)
├── models/
│   └── student_session.rb             # MODIFY: add part completion tracking methods
├── views/
│   └── student/
│       ├── subjects/
│       │   ├── show.html.erb          # MODIFY: grouped parts, objective_text, completion badges
│       │   ├── _specific_presentation.html.erb  # NEW: mise en situation spécifique partial
│       │   ├── _unanswered_questions.html.erb   # NEW: questions non répondues partial
│       │   └── _completion.html.erb             # NEW: page "Bravo !!" partial
│       └── questions/
│           └── show.html.erb          # MODIFY: "Fin de la partie" button, review-mode redirect
└── spec/
    ├── models/
    │   └── student_session_spec.rb    # MODIFY: add part completion specs
    ├── requests/
    │   └── student/
    │       └── subjects_spec.rb       # MODIFY: add complete_part action specs
    └── features/
        └── student/
            └── subject_workflow_spec.rb  # NEW: full workflow feature specs
```

**Structure Decision**: Rails standard structure. All changes in existing student namespace. New partials for the 3 new screens (specific presentation, unanswered questions, completion). No new models or migrations.

## Design Decisions

### D1: Part completion tracking via `progression` JSONB

Store part completion status in the existing `progression` JSONB field of `StudentSession`, using a `parts_completed` key:

```json
{
  "42": { "seen": true, "answered": true },
  "parts_completed": [3, 7]
}
```

**Rationale**: Avoids a new migration. The `progression` field already tracks session state. Adding a top-level key (`parts_completed` as array of part IDs) is simple, queryable, and doesn't conflict with question-level tracking (question IDs are numeric strings, `parts_completed` is a distinct key).

**Methods on StudentSession**:
- `mark_part_completed!(part_id)` — adds part_id to `parts_completed` array
- `part_completed?(part_id)` — checks membership
- `all_parts_completed?` — checks if all filtered parts are in `parts_completed`
- `subject_completed?` — true if `completed_at` is set (subject explicitly terminated)
- `mark_subject_completed!` — sets `completed_at` timestamp in progression

### D2: Workflow routing in subjects#show

The `show` action becomes a workflow router with this priority:

1. **Scope selection needed** → render scope selection screen
2. **Subject completed + all parts completed** → render parts list (relecture mode)
3. **All parts completed + unanswered questions remain** → render unanswered questions page
4. **All parts completed + all questions answered** → render completion page ("Bravo !!")
5. **First visit (no answers yet, no parts completed)** → render mise en situation commune + parts list
6. **All common parts completed (or scope is specific_only) + specific parts exist in scope + !specific_presentation_seen?** → render specific presentation
7. **Default** → redirect to first undone question in selected part

### D3: Navigation context via query parameter

When accessing a question from the unanswered questions page, pass `?from=review` as a query parameter. The questions controller checks this param to determine whether "Question suivante" should redirect to the unanswered questions page or to the next question in normal sequence.

**Rationale**: Simpler than storing navigation context in session. Stateless. The param is lost on sidebar navigation, which is the desired behavior (sidebar = normal navigation mode).

### D4: Complete part action

New route: `PATCH /subjects/:id/complete_part/:part_id` → `student/subjects#complete_part`

This action:
1. Calls `mark_part_completed!(part_id)` on the session
2. Redirects to `subject#show` (which routes to the appropriate next screen)

The "Fin de la partie" button in question views links to this action instead of to subjects#show directly.

### D5: Parts display with section grouping

On `subjects#show`, parts are grouped using `group_by(&:section_type)` when scope is "full". For "common_only" or "specific_only" scopes, parts are listed flat without section headers. Each part shows:
- Number + title
- `objective_text` (if present)
- Question count
- Completion badge (coche) if `part_completed?(part.id)`

The "Commencer" button at the bottom links to the first undone question of the first incomplete part.

### D6: Subject termination

New route: `PATCH /subjects/:id/complete` → `student/subjects#complete`

This action:
1. Calls `mark_subject_completed!` on the session
2. Redirects to `subject#show` (which renders the completion page)

## Complexity Tracking

No constitution violations. No complexity justification needed.
