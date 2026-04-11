# Implementation Plan: Fix T050 UI Bugs

**Branch**: `028-fix-t050-ui-bugs` | **Date**: 2026-04-11 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/028-fix-t050-ui-bugs/spec.md`

## Summary

Fix 6 UI bugs found during manual testing T050 on the student question page: wrong starting question order, context text not separated, raw source labels, inconsistent badge colors, data hints position in correction, and missing specific presentation on part transition.

## Technical Context

**Language/Version**: Ruby 3.3+ / Rails 8.1
**Primary Dependencies**: Hotwire (Turbo Streams, Stimulus), ViewComponent, Tailwind CSS 4
**Storage**: PostgreSQL via Neon (JSONB `progression` and `tutor_state` in `student_sessions`)
**Testing**: RSpec + FactoryBot + Capybara (headless Chrome)
**Target Platform**: Web (responsive, mobile-first)
**Project Type**: Web application (fullstack Rails)
**Constraints**: Simple/readable code over performance (MVP context)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Fullstack Rails — Hotwire Only | ✅ | All changes are views + controller, no SPA |
| II. RGPD & Protection des mineurs | ✅ | No data model changes, no new data collected |
| III. Security | ✅ | No secret handling changes |
| IV. Testing | ✅ | Existing specs updated + new specs for new behavior |
| V. Performance & Simplicity | ✅ | Simple view reordering and helper method |
| VI. Development Workflow | ✅ | Feature branch, PR, CI validation |

## Project Structure

### Source Code (files to modify)

```text
app/
├── controllers/
│   └── student/
│       ├── subjects_controller.rb    # Bug 1 (part ordering), Bug 6 (specific presentation)
│       └── questions_controller.rb   # Bug 6 (mark specific presentation seen)
├── helpers/
│   └── student/
│       └── data_hints_helper.rb      # NEW — Bug 3 (source labels) + Bug 4 (badge colors)
├── views/
│   └── student/
│       ├── questions/
│       │   ├── show.html.erb         # Bug 2 (context card), Bug 4 (badge colors in data hints)
│       │   ├── _correction.html.erb  # Bug 5 (reorder data hints to top), Bug 3 (source labels)
│       │   └── _correction_button.html.erb  # Bug 3+4 (source labels + colors in pre-correction)
│       └── subjects/
│           └── show.html.erb         # Bug 6 (specific presentation routing)
spec/
├── features/
│   ├── student_question_navigation_spec.rb  # Update for Bug 2 context card
│   └── student/
│       └── subject_workflow_spec.rb         # Update for Bug 1, Bug 6
├── helpers/
│   └── student/
│       └── data_hints_helper_spec.rb        # NEW — Bug 3 + Bug 4
```

## Implementation Phases

### Phase A: Helper for source labels + badge colors (Bug 3 + Bug 4)

**Create `app/helpers/student/data_hints_helper.rb`** with two methods:

1. `hint_source_label(source)` — translates raw source keys:
   - `"question_context"` → `"Contexte"`
   - `"mise_en_situation"` → `"Présentation"`
   - `"enonce"` → `"Énoncé"`
   - `"tableau_sujet"` → `"Tableau du sujet"`
   - `/\ADT/i` → kept as-is (e.g. "DT1")
   - `/\ADR/i` → kept as-is (e.g. "DR1")
   - fallback → capitalize source

2. `hint_badge_color(source)` — returns BadgeComponent color:
   - `/\ADT/i` → `:blue`
   - `/\ADR/i` → `:amber`
   - all others → `:slate`

**Unit specs**: `spec/helpers/student/data_hints_helper_spec.rb`

### Phase B: Reorder data hints in correction partial (Bug 5)

**Modify `app/views/student/questions/_correction.html.erb`**:
- Move the "Où trouver les données ?" section from after correction+explanation to **before** the correction section (first element in the partial).
- Use helper methods from Phase A for labels and colors.

**Modify `app/views/student/questions/show.html.erb`**:
- Remove the pre-correction "Où trouver les données ?" collapsible section (lines 154-176) since it now appears inside the correction partial.
- Remove the standalone "Où trouver les données ?" button (line 155-161).

**Modify `app/views/student/questions/_correction_button.html.erb`**:
- Remove the data hints collapsible from this partial too (it was extracted for the skip_spotting turbo_stream).

### Phase C: Context card separation (Bug 2)

**Modify `app/views/student/questions/show.html.erb`**:
- Extract `@question.context_text` from inside the question card (lines 122-124).
- Render it in a separate card above the question card, with distinct styling (lighter background, italic text, no question number).
- Only render the context card if `context_text.present?`.

### Phase D: Fix starting question order (Bug 1)

**Investigate `app/controllers/student/subjects_controller.rb`**:
- In `all_parts_for_subject` (line 187-194), common parts are already listed first.
- The bug may be in `target_part` or `first_incomplete_part_question` — if parts have equal position values, the specific part may sort first.
- Fix: ensure `target_part` explicitly prefers common parts when positions are equal.
- Also check `first_undone_question` in `StudentSession` model.

### Phase E: Specific presentation on part transition (Bug 6)

**Modify `app/controllers/student/subjects_controller.rb`**:
- In `show` action step 7 (line 80-88): when `target_part` returns a specific part and `specific_presentation_seen?` is false, redirect through the specific presentation flow instead of directly to the question.
- Ensure `should_show_specific_presentation?` is checked before redirecting to a question in a specific part.

**Also check `complete_part` action** (line 103+):
- The existing logic at line 136-146 already handles this for part completion transitions.
- Verify that direct sidebar navigation (with `part_id` param pointing to a specific part) also triggers the presentation check.

### Phase F: Spec updates

**Update existing specs**:
- `spec/features/student_question_navigation_spec.rb` — update selectors if context card changes DOM structure.
- `spec/features/student/subject_workflow_spec.rb` — verify starting question order and specific presentation flow.

**New specs**:
- `spec/helpers/student/data_hints_helper_spec.rb` — test `hint_source_label` and `hint_badge_color`.

## Verification

```bash
# Helper specs
bundle exec rspec spec/helpers/student/data_hints_helper_spec.rb

# Feature specs
bundle exec rspec spec/features/student_question_navigation_spec.rb
bundle exec rspec spec/features/student/subject_workflow_spec.rb

# Full suite
bundle exec rspec

# Manual QA
# 1. Start a complete subject → verify Q1.1 (common) is first
# 2. View a question with context_text → verify separate cards
# 3. Reveal correction → verify "Où trouver les données ?" is at top
# 4. Check DT badges are blue, DR badges are amber in all sections
# 5. Complete common part → verify specific presentation appears
```
