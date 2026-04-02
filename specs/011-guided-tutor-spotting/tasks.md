# Tasks: Tuteur guidé — Micro-tâches de repérage

**Input**: Design documents from `/specs/011-guided-tutor-spotting/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md
**TDD**: Required (Constitution IV)

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to

---

## Phase 1: Setup

**Purpose**: Migration + model foundation

- [ ] T001 Create migration `add_tutor_state_to_student_sessions` adding JSONB column `tutor_state` (default `{}`, null false) in `db/migrate/`
- [ ] T002 Run migration and verify schema in `db/schema.rb`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Model helpers + routes + controller skeleton — MUST complete before user stories

- [ ] T003 Write RSpec tests for `StudentSession` tutor_state helpers in `spec/models/student_session_spec.rb`: `question_step`, `set_question_step!`, `store_spotting!`, `spotting_data`, `spotting_completed?`, `tutored_active?`
- [ ] T004 Implement tutor_state helpers in `app/models/student_session.rb` — make tests pass
- [ ] T005 Add tutor routes in `config/routes.rb`: POST `activate`, POST `verify_spotting`, POST `skip_spotting` under `/:access_code/subjects/:subject_id/questions/:question_id/tutor/`
- [ ] T006 Create `app/controllers/student/tutor_controller.rb` skeleton with `activate`, `verify_spotting`, `skip_spotting` actions (empty bodies, correct before_actions)

**Checkpoint**: Foundation ready — model helpers tested, routes and controller wired

---

## Phase 3: User Story 1 — Repérage avant correction (Priority: P1) 🎯 MVP

**Goal**: Encart "Avant de répondre" bloquant la correction — radio type de tâche + checkboxes sources + feedback immédiat

**Independent Test**: Un élève en mode tuteur complète le repérage, reçoit un feedback, puis accède à la correction

### Tests for User Story 1

> **Write tests FIRST, ensure they FAIL before implementation**

- [ ] T007 [US1] Write request specs for `TutorController#verify_spotting` in `spec/requests/student/tutor_spec.rb`: correct answers → stores feedback + returns Turbo Stream, wrong answers → stores with missed/extra sources, missing data_hints → only task type validated
- [ ] T008 [US1] Write request specs for `TutorController#skip_spotting` in `spec/requests/student/tutor_spec.rb`: sets step to skipped, returns Turbo Stream
- [ ] T009 [US1] Write feature spec in `spec/features/student_spotting_spec.rb`: 7 acceptance scenarios from spec (correct repérage, wrong type, missed source, extra source, correction blocked, skip, revisit shows feedback)

### Implementation for User Story 1

- [ ] T010 [US1] Implement `verify_spotting` action in `app/controllers/student/tutor_controller.rb`: validate task_type against `question.answer_type`, validate sources against normalized `data_hints`, store result via `store_spotting!`, respond with Turbo Stream replacing spotting frame
- [ ] T011 [US1] Implement `skip_spotting` action in `app/controllers/student/tutor_controller.rb`: set step to `skipped`, respond with Turbo Stream
- [ ] T012 [P] [US1] Create `app/views/student/tutor/_spotting_card.html.erb`: radio buttons for task type (correct + 2-3 distractors from `TASK_TYPE_LABELS`), checkboxes for sources (from subject's available docs + data_hints categories), [Vérifier] button + {passer} link. Wrapped in `turbo_frame_tag "spotting_question_#{question.id}"`
- [ ] T013 [P] [US1] Create `app/views/student/tutor/_spotting_feedback.html.erb`: correct/incorrect for task type, sources correct/missed/extra with location from `data_hints`. Same turbo_frame_tag wrapping
- [ ] T014 [P] [US1] Create `app/javascript/controllers/spotting_controller.js`: manages radio selection highlight, checkbox interaction, submit POST to verify_spotting, skip POST to skip_spotting
- [ ] T015 [US1] Modify `app/views/student/questions/show.html.erb`: when `session.tutored?` and `!session.spotting_completed?(question.id)` → render spotting_card instead of correction button. When completed → render spotting_feedback + correction button. When autonomous → unchanged
- [ ] T016 [US1] Run request specs + feature specs — verify all pass

**Checkpoint**: Repérage fonctionnel — élève en mode tuteur voit l'encart, peut vérifier ou passer, correction bloquée jusqu'à interaction

---

## Phase 4: User Story 4 — Mode autonome inchangé (Priority: P1)

**Goal**: Vérifier zéro régression sur le mode autonome

**Independent Test**: Un élève en mode autonome navigue normalement sans encart de repérage

### Tests for User Story 4

- [ ] T017 [US4] Write feature spec in `spec/features/student_autonomous_regression_spec.rb`: élève autonome ne voit PAS l'encart repérage, correction accessible directement, navigation inchangée

### Implementation for User Story 4

- [ ] T018 [US4] Verify existing feature specs still pass (autonomous mode paths) — run full `spec/features/` suite via CI push

**Checkpoint**: Mode autonome inchangé, aucune régression

---

## Phase 5: User Story 2 — Activation du mode tuteur (Priority: P2)

**Goal**: Bannière proposant le mode tuteur sur la page de mise en situation

**Independent Test**: Un élève autonome avec clé API voit la bannière, clique, et le mode tuteur s'active

### Tests for User Story 2

- [ ] T019 [US2] Write request spec for `TutorController#activate` in `spec/requests/student/tutor_spec.rb`: updates session mode to tutored, redirects back
- [ ] T020 [US2] Write feature spec in `spec/features/student_tutor_activation_spec.rb`: 4 acceptance scenarios (banner visible with API key, hidden without, hidden if already tutored, activation enables spotting)

### Implementation for User Story 2

- [ ] T021 [US2] Implement `activate` action in `app/controllers/student/tutor_controller.rb`: update session mode to `:tutored`, redirect back
- [ ] T022 [P] [US2] Create `app/views/student/tutor/_tutor_banner.html.erb`: banner with message + [Activer le mode tuteur] button, POST to activate path
- [ ] T023 [US2] Modify `app/views/student/subjects/show.html.erb`: render `_tutor_banner` when `session.autonomous?` and `current_student.api_key.present?`
- [ ] T024 [US2] Run feature specs — verify activation + banner visibility

**Checkpoint**: Bannière fonctionnelle — activation du mode tuteur depuis la page mise en situation

---

## Phase 6: User Story 3 — Chat adaptatif avec contexte de repérage (Priority: P3)

**Goal**: Le tuteur IA connaît le résultat du repérage et adapte ses réponses

**Independent Test**: Un élève qui a raté le repérage ouvre le chat, le tuteur mentionne les sources manquées

### Tests for User Story 3

- [ ] T025 [US3] Write unit spec for `BuildTutorPrompt#spotting_context` in `spec/services/build_tutor_prompt_spec.rb`: prompt includes sources manquées when spotting failed, includes positive message when spotting correct, empty when no spotting data
- [ ] T026 [US3] Write feature spec in `spec/features/student_tutor_chat_spec.rb`: 3 acceptance scenarios (chat context with missed sources, correct sources, autonomous mode unchanged)

### Implementation for User Story 3

- [ ] T027 [US3] Add `spotting_context` method to `app/services/build_tutor_prompt.rb`: reads `tutor_state` from student session, formats spotting result into system prompt section
- [ ] T028 [US3] Modify `app/views/student/questions/_correction.html.erb`: add {expliquer la correction} link when `session.tutored?`, using `data-action="click->chat#openWithMessage"` with pre-filled message
- [ ] T029 [US3] Add `openWithMessage(event)` method to `app/javascript/controllers/chat_controller.js`: reads message from `data-chat-message-param`, opens drawer, auto-sends the message
- [ ] T030 [US3] Run feature specs — verify chat context and auto-message

**Checkpoint**: Chat adaptatif fonctionnel — tuteur contextualise ses réponses selon le repérage

---

## Phase 7: Polish & Cross-Cutting Concerns

- [ ] T031 Push to GitHub and verify full CI passes (all 4 check jobs)
- [ ] T032 Run `quickstart.md` manual validation end-to-end
- [ ] T033 Verify mobile responsive: spotting card renders correctly on small screens

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies
- **Foundational (Phase 2)**: Depends on Phase 1
- **US1 (Phase 3)**: Depends on Phase 2 — **MVP target**
- **US4 (Phase 4)**: Depends on Phase 3 (regression check)
- **US2 (Phase 5)**: Depends on Phase 2 only (independent of US1 implementation, but logically after US1)
- **US3 (Phase 6)**: Depends on Phase 2 + US1 (needs spotting data to contextualize chat)
- **Polish (Phase 7)**: Depends on all stories

### Within Each User Story

- Tests MUST be written and FAIL before implementation (Constitution IV)
- Controller logic before view partials
- View partials + Stimulus controller in parallel (different files)
- Feature specs run after all story code is in place

### Parallel Opportunities

- T012, T013, T014 can run in parallel (different files: 2 partials + 1 JS controller)
- T022 can run in parallel with T021 (partial vs controller)
- US2 (Phase 5) can start while US4 (Phase 4) CI runs

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Migration
2. Complete Phase 2: Model helpers + routes + controller skeleton
3. Complete Phase 3: Spotting encart + verify + feedback
4. **STOP and VALIDATE**: Push to CI, manual test
5. Deploy if green

### Incremental Delivery

1. Setup + Foundation → Model + routes ready
2. Add US1 (spotting) → Test → Push (MVP!)
3. Add US4 (regression check) → CI confirms no breakage
4. Add US2 (banner activation) → Test → Push
5. Add US3 (chat adaptatif) → Test → Push
6. Polish → Final CI → Done

---

## Notes

- No IA calls needed for spotting (all data in DB) — fast, cheap, reliable
- Turbo Stream responses for spotting verify/skip — no full page reload
- Constitution TDD: every task has tests written first
- Commit after each task or logical group
