# Tasks: Workflow sujet complet élève

**Input**: Design documents from `/specs/021-student-subject-workflow/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md

**Tests**: Required (Constitution Principle IV — TDD mandatory, feature specs for every user-facing behavior).

**Organization**: Tasks grouped by user story. US1+US2 are P1 (core navigation), US3+US4 are P2 (specific presentation + review), US5+US6 are P3 (polish).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2)
- Exact file paths included

---

## Phase 1: Setup (Routes & Configuration)

**Purpose**: Add new routes needed for the workflow

- [x] T001 Add `complete_part` and `complete` routes in config/routes.rb
- [x] T001b Verify Subject delegates `specific_presentation` to ExamSession (like `common_presentation`). If missing, add delegation in app/models/subject.rb

---

## Phase 2: Foundational (Model Methods)

**Purpose**: Core StudentSession methods that ALL user stories depend on

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

### Tests

- [x] T002 Write unit specs for part completion methods (`mark_part_completed!`, `part_completed?`, `all_parts_completed?`) in spec/models/student_session_spec.rb
- [x] T003 [P] Write unit specs for subject completion methods (`subject_completed?`, `mark_subject_completed!`) in spec/models/student_session_spec.rb
- [x] T004 [P] Write unit specs for `specific_presentation_seen?`, `mark_specific_presentation_seen!`, `unanswered_questions` in spec/models/student_session_spec.rb

### Implementation

- [x] T005 Implement part completion methods (`mark_part_completed!`, `part_completed?`, `all_parts_completed?`) in app/models/student_session.rb
- [x] T006 [P] Implement subject completion methods (`subject_completed?`, `mark_subject_completed!`) in app/models/student_session.rb
- [x] T007 [P] Implement `specific_presentation_seen?`, `mark_specific_presentation_seen!`, `unanswered_questions` in app/models/student_session.rb

**Checkpoint**: All model methods pass unit tests. No view/controller changes yet.

---

## Phase 3: User Story 1 — Liste des parties avec objectifs et séparation commune/spécifique (Priority: P1) 🎯 MVP

**Goal**: L'élève voit les parties regroupées par section (COMMUNE / SPÉCIFIQUE) avec objectifs et badges de progression.

**Independent Test**: Accéder à la page sujet avec un sujet complet et vérifier le regroupement, les objectifs, le bouton en bas.

### Tests

- [x] T008 [US1] Write feature spec: parts grouped by section_type with headers "PARTIE COMMUNE" / "PARTIE SPÉCIFIQUE" on scope "complet" in spec/features/student/subject_workflow_spec.rb
- [x] T009 [US1] Write feature spec: objective_text displayed under each part title in spec/features/student/subject_workflow_spec.rb
- [x] T010 [US1] Write feature spec: "Commencer" button at bottom of parts list in spec/features/student/subject_workflow_spec.rb
- [x] T011 [US1] Write feature spec: single-scope (common_only / specific_only) shows flat list without section headers in spec/features/student/subject_workflow_spec.rb

### Implementation

- [x] T012 [US1] Modify subjects#show parts display: group by section_type with en-têtes, add objective_text in app/views/student/subjects/show.html.erb
- [x] T013 [US1] Move "Commencer" button to bottom of parts list, link to first undone question of first incomplete part in app/views/student/subjects/show.html.erb
- [x] T014 [US1] Update subjects#show controller logic: pass grouped parts and completion status to view in app/controllers/student/subjects_controller.rb

**Checkpoint**: Parts list displays correctly with grouping, objectives, and button at bottom.

---

## Phase 4: User Story 2 — Navigation séquentielle avec transitions entre parties (Priority: P1)

**Goal**: "Fin de la partie" remplace "Retour aux sujets" sur la dernière question. Le bouton redirige via complete_part et la page du sujet affiche les parties terminées avec marqueur visuel.

**Independent Test**: Naviguer jusqu'à la dernière question d'une partie, vérifier le bouton "Fin de la partie", cliquer et vérifier le retour à la page du sujet avec badge "Terminé".

### Tests

- [x] T015 [US2] Write feature spec: last question shows "Fin de la partie" button instead of "Retour aux sujets" in spec/features/student/subject_workflow_spec.rb
- [x] T016 [US2] Write feature spec: clicking "Fin de la partie" marks part completed and redirects to subject page in spec/features/student/subject_workflow_spec.rb
- [x] T017 [US2] Write feature spec: completed part shows visual badge (coche) on subject page in spec/features/student/subject_workflow_spec.rb
- [x] T018 [US2] Write request spec for complete_part action in spec/requests/student/subjects_spec.rb

### Implementation

- [x] T019 [US2] Implement `complete_part` action in app/controllers/student/subjects_controller.rb
- [x] T020 [US2] Modify question navigation: replace "Retour aux sujets" with "Fin de la partie" on last question, link to complete_part route in app/views/student/questions/show.html.erb
- [x] T021 [US2] Update subjects#show: display completion badge on completed parts in app/views/student/subjects/show.html.erb

**Checkpoint**: Full part-to-part navigation works. Student can complete a part and see it marked on the subject page.

---

## Phase 5: User Story 3 — Mise en situation spécifique entre les deux parties (Priority: P2)

**Goal**: Afficher la mise en situation spécifique (`specific_presentation`) comme écran intermédiaire avant les questions de la partie spécifique.

**Independent Test**: Terminer la partie commune, revenir à la page du sujet, et vérifier que la mise en situation spécifique s'affiche.

### Tests

- [x] T022 [US3] Write feature spec: specific presentation shown when starting specific part (if specific_presentation present) in spec/features/student/subject_workflow_spec.rb
- [x] T023 [US3] Write feature spec: specific presentation skipped when specific_presentation is empty in spec/features/student/subject_workflow_spec.rb

### Implementation

- [x] T024 [US3] Create specific presentation partial with text and "Commencer" button at bottom in app/views/student/subjects/_specific_presentation.html.erb
- [x] T025 [US3] Update subjects#show workflow routing: render specific presentation when specific part is next and not yet seen in app/controllers/student/subjects_controller.rb

**Checkpoint**: Specific presentation displays between parts when available, skipped when empty.

---

## Phase 6: User Story 4 — Page des questions non répondues (Priority: P2)

**Goal**: Après "Fin de la partie" sur toutes les parties, afficher les questions non vues/non répondues. "Revenir à cette question" ouvre la question avec `?from=review`, "Question suivante" ramène à la page review.

**Independent Test**: Terminer les deux parties sans répondre à toutes les questions, vérifier que la page des questions non répondues apparaît.

### Tests

- [x] T026 [US4] Write feature spec: unanswered questions page shown after all parts completed with remaining questions in spec/features/student/subject_workflow_spec.rb
- [x] T027 [US4] Write feature spec: "Revenir à cette question" opens question, "Question suivante" redirects back to unanswered page in spec/features/student/subject_workflow_spec.rb
- [x] T028 [US4] Write feature spec: all questions answered after all parts → skip to completion page in spec/features/student/subject_workflow_spec.rb

### Implementation

- [x] T029 [US4] Create unanswered questions partial with question list and "Terminer le sujet" button in app/views/student/subjects/_unanswered_questions.html.erb
- [x] T030 [US4] Update subjects#show workflow routing: render unanswered page when all parts completed + questions remain in app/controllers/student/subjects_controller.rb
- [x] T031 [US4] Modify question navigation: when `?from=review`, "Question suivante" redirects to subject#show (unanswered page) in app/views/student/questions/show.html.erb

**Checkpoint**: Unanswered questions page works. Review-mode navigation redirects correctly.

---

## Phase 7: User Story 5 — Page de félicitations (Priority: P3)

**Goal**: Page "Bravo !!" quand le sujet est terminé (toutes questions répondues ou "Terminer le sujet" cliqué).

**Independent Test**: Terminer toutes les questions et vérifier la page "Bravo".

### Tests

- [x] T032 [US5] Write feature spec: completion page "Bravo !!" shown when all questions answered after all parts completed in spec/features/student/subject_workflow_spec.rb
- [x] T033 [US5] Write feature spec: "Terminer le sujet" triggers completion page in spec/features/student/subject_workflow_spec.rb
- [x] T034 [US5] Write feature spec: re-entering completed subject shows relecture mode (no re-trigger of Bravo) in spec/features/student/subject_workflow_spec.rb
- [x] T035 [US5] Write request spec for complete action in spec/requests/student/subjects_spec.rb

### Implementation

- [x] T036 [US5] Create completion partial "Bravo !!" with "Revenir aux sujets" button in app/views/student/subjects/_completion.html.erb
- [x] T037 [US5] Implement `complete` action in app/controllers/student/subjects_controller.rb
- [x] T038 [US5] Update subjects#show workflow routing: render completion page or relecture mode based on subject_completed? in app/controllers/student/subjects_controller.rb

**Checkpoint**: Completion ceremony works. Re-entry shows relecture mode.

---

## Phase 8: User Story 6 — Placement cohérent des boutons d'action (Priority: P3)

**Goal**: Tous les boutons d'action (Commencer, Continuer, Fin de la partie, Terminer le sujet) sont en bas de leur section.

**Independent Test**: Parcourir le workflow complet et vérifier la position des boutons.

- [x] T039 [US6] Audit and fix button placement consistency across all modified views: show.html.erb, _specific_presentation.html.erb, _unanswered_questions.html.erb, _completion.html.erb, questions/show.html.erb

**Checkpoint**: All action buttons consistently at bottom of their sections.

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: Edge cases, regressions, cleanup

- [ ] T040 Verify legacy subjects (no exam_session) still work unchanged — add regression feature spec in spec/features/student/subject_workflow_spec.rb
- [ ] T041 Verify sidebar navigation still works correctly (no review-mode redirect from sidebar) in spec/features/student/subject_workflow_spec.rb
- [ ] T042 [P] Write feature spec: student quits mid-workflow, re-enters subject, parts_completed and progression state preserved in spec/features/student/subject_workflow_spec.rb
- [ ] T043 Run quickstart.md manual validation (full workflow end-to-end)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies — start immediately
- **Phase 2 (Foundational)**: Depends on Phase 1 — BLOCKS all user stories
- **Phase 3 (US1)** + **Phase 4 (US2)**: Depend on Phase 2. US1 and US2 can run in parallel (different view sections)
- **Phase 5 (US3)**: Depends on Phase 2. Independent of US1/US2
- **Phase 6 (US4)**: Depends on Phase 4 (needs complete_part mechanism). Independent of US3
- **Phase 7 (US5)**: Depends on Phase 6 (needs unanswered flow for "Terminer le sujet")
- **Phase 8 (US6)**: Depends on all previous phases (audit all views)
- **Phase 9 (Polish)**: Depends on all previous phases

### User Story Dependencies

- **US1 (P1)**: Independent after foundational
- **US2 (P1)**: Independent after foundational (can parallel with US1)
- **US3 (P2)**: Independent after foundational (can parallel with US1/US2)
- **US4 (P2)**: Depends on US2 (needs complete_part)
- **US5 (P3)**: Depends on US4 (needs unanswered flow + complete action)
- **US6 (P3)**: Depends on all (audit pass)

### Within Each User Story

- Tests MUST be written and FAIL before implementation (TDD — Constitution IV)
- Controller before views (where applicable)
- Core implementation before integration

### Parallel Opportunities

- T002, T003, T004 can run in parallel (different method groups)
- T005, T006, T007 can run in parallel (different method groups)
- US1 (T008-T014) and US2 (T015-T021) can run in parallel
- US3 (T022-T025) can run in parallel with US1/US2
- T040 and T041 can run in parallel (different regression areas)

---

## Implementation Strategy

### MVP First (US1 + US2)

1. Phase 1: Routes setup
2. Phase 2: Model methods (TDD)
3. Phase 3: US1 — Parts list with grouping + objectives
4. Phase 4: US2 — "Fin de la partie" navigation
5. **STOP and VALIDATE**: Test parts grouping + part completion flow
6. Push + CI green

### Incremental Delivery

1. Setup + Foundational → Model layer ready
2. US1 + US2 → Core navigation MVP → Push + CI
3. US3 → Specific presentation → Push + CI
4. US4 → Unanswered questions page → Push + CI
5. US5 → Completion ceremony → Push + CI
6. US6 + Polish → Final cleanup → Push + CI + PR

---

## Notes

- No migration needed — all state in existing `progression` JSONB
- Constitution IV mandates TDD: write failing specs before implementation
- Feature specs run on CI (slow locally — Constitution IV note)
- Interface in French, code in English
- One concern per commit (feedback memory)
- Also updated existing specs for regressions (button text "Commencer les questions" → "Commencer", "Retour aux sujets" → "Fin de la partie")
