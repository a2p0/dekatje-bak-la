# Tasks: 028 — Fix T050 UI Bugs

**Input**: Design documents from `/specs/028-fix-t050-ui-bugs/`
**Prerequisites**: plan.md, spec.md, research.md

**Tests**: Feature specs required (constitution IV — Capybara for every user-facing behavior).

**Organization**: Tasks grouped by user story for independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1–US6)

## User Stories (from spec)

- **US1**: Question navigation starts at the common part (P1)
- **US2**: Context text in a separate card above the question (P1)
- **US3**: Human-readable source labels in data hints (P2)
- **US4**: Consistent badge colors for DT/DR (P2)
- **US5**: Data hints at top of correction partial (P2)
- **US6**: Specific presentation shown when starting specific part (P1)

---

## Phase 1: Foundational — Helper for data hints (Bug 3 + Bug 4)

**Purpose**: Create the helper used by all data hints rendering. Blocks US3, US4, US5.

- [x] T001 Create `app/helpers/student/data_hints_helper.rb` with `hint_source_label(source)` and `hint_badge_color(source)` methods
- [x] T002 Add unit specs in `spec/helpers/student/data_hints_helper_spec.rb` — test all source key translations and badge color mappings

**Checkpoint**: Helper ready, unit specs green.

---

## Phase 2: User Story 5 — Data hints at top of correction (Priority: P2)

**Goal**: "Où trouver les données ?" appears before correction text.

**Independent Test**: Reveal a correction → data hints section is the first element visible.

- [x] T003 [US5] Move data hints section to the top of `app/views/student/questions/_correction.html.erb` (before the correction div). Use `hint_source_label` and `hint_badge_color` helpers for rendering.
- [x] T004 [US5] Remove pre-correction "Où trouver les données ?" collapsible from `app/views/student/questions/show.html.erb` (lines 154-176) and the standalone button (lines 155-161)
- [x] T005 [US5] Remove data hints collapsible from `app/views/student/questions/_correction_button.html.erb`

**Checkpoint**: Correction shows data hints at top. No duplicate "Où trouver les données?" sections.

---

## Phase 3: User Story 3 + 4 — Source labels and badge colors (Priority: P2)

**Goal**: Human-readable labels and consistent colors in all data hints views.

**Independent Test**: View correction → badges show "Contexte" (not "question_context"), DT=blue, DR=amber.

- [x] T006 [US3] [US4] Verify `_correction.html.erb` uses `hint_source_label` and `hint_badge_color` (done in T003). If any other view renders data hints, update it too.
- [x] T007 [US3] [US4] Update `app/views/student/tutor/_spotting_feedback.html.erb` — use `hint_source_label` for missed source badges if applicable

**Checkpoint**: All source labels are human-readable, all badge colors are consistent.

---

## Phase 4: User Story 2 — Context card separation (Priority: P1)

**Goal**: `context_text` rendered in its own card above the question card.

**Independent Test**: Visit a question with context text → two distinct cards visible (context above, question below).

- [x] T008 [US2] Extract `context_text` from inside the question card in `app/views/student/questions/show.html.erb` (lines 122-124) and render it in a separate card above, with lighter styling and no question number. Only render if `context_text.present?`.
- [x] T009 [US2] Update feature specs in `spec/features/student_question_navigation_spec.rb` if selectors changed by the new DOM structure.

**Checkpoint**: Context card visually distinct and above the question card.

---

## Phase 5: User Story 1 — Starting question order (Priority: P1)

**Goal**: Subject always starts at Q1.1 (common), not QA.1 (specific).

**Independent Test**: Start a subject with common + specific parts → first question is from the common section.

- [x] T010 [US1] Investigate `all_parts_for_subject` and `target_part` in `app/controllers/student/subjects_controller.rb` — verify common parts sort before specific parts. Fix if position values cause wrong ordering.
- [x] T011 [US1] Update/add feature spec in `spec/features/student/subject_workflow_spec.rb` to verify that starting a complete subject navigates to the first common question, not a specific one.

**Checkpoint**: Subject always starts with the common section's first question.

---

## Phase 6: User Story 6 — Specific presentation on part transition (Priority: P1)

**Goal**: Specific presentation shown before first specific question.

**Independent Test**: Complete common part → see specific presentation → then first specific question.

- [x] T012 [US6] In `app/controllers/student/subjects_controller.rb` step 7 (line 80-88), add check: if `target_part` returns a specific part and `specific_presentation_seen?` is false, redirect through the specific presentation flow instead of directly to the question.
- [x] T013 [US6] Verify that sidebar navigation to a specific part (with `part_id` param) also triggers the specific presentation check.
- [x] T014 [US6] Update/add feature spec in `spec/features/student/subject_workflow_spec.rb` to verify specific presentation is shown when transitioning to the specific section.

**Checkpoint**: Specific presentation always shown before first specific question.

---

## Phase 7: Polish & Verification

**Purpose**: Full regression check.

- [x] T015 Run `bundle exec rspec` — full spec suite, no regressions
- [ ] T016 Manual QA: verify all 6 bugs are fixed (light + dark mode)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Helper)**: No dependencies — start immediately. BLOCKS Phase 2, 3.
- **Phase 2 (US5)**: Depends on Phase 1 helper.
- **Phase 3 (US3+US4)**: Depends on Phase 1 helper. Can run in parallel with Phase 2.
- **Phase 4 (US2)**: Independent — no dependency on other phases.
- **Phase 5 (US1)**: Independent — no dependency on other phases.
- **Phase 6 (US6)**: Independent — no dependency on other phases.
- **Phase 7 (Polish)**: Depends on all phases complete.

### Parallel Opportunities

- Phase 2 and Phase 3 can run in parallel (different files, shared helper from Phase 1)
- Phase 4, Phase 5, and Phase 6 are fully independent — can all run in parallel
- T002 can run in parallel with T001 (TDD: write spec first)

---

## Implementation Strategy

### MVP First

1. Phase 1: Helper (foundation for labels + colors)
2. Phase 2: Data hints at top of correction (most visible improvement)
3. Phase 4: Context card separation
4. **VALIDATE**: Manual QA on question page
5. Phase 5 + 6: Navigation fixes

### Incremental Delivery

1. Helper + US5 (correction reorder) → immediate visual improvement
2. US3+US4 (labels + colors) → polish data hints
3. US2 (context card) → question page clarity
4. US1 + US6 (navigation) → correct flow
5. Full regression → deploy

---

## Summary

| Metric | Count |
|---|---|
| **Total tasks** | 16 |
| **US1 (Start order)** | 2 tasks |
| **US2 (Context card)** | 2 tasks |
| **US3+US4 (Labels + colors)** | 2 tasks |
| **US5 (Data hints position)** | 3 tasks |
| **US6 (Specific presentation)** | 3 tasks |
| **Foundational** | 2 tasks |
| **Polish** | 2 tasks |
| **Parallel opportunities** | 3 groups identified |

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Feature specs are mandatory (constitution IV)
- Commit after each task or logical group (constitution VI — one concern per commit)
- Run CI after each phase checkpoint
