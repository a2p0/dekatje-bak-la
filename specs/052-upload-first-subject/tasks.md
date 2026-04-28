# Tasks: Upload-First Subject Creation Workflow

**Input**: Design documents from `/specs/052-upload-first-subject/`
**Prerequisites**: plan.md ✅, spec.md ✅, research.md ✅, data-model.md ✅, contracts/ ✅, quickstart.md ✅

**Constitution**: TDD is mandatory — RSpec unit specs written and failing BEFORE production code. Capybara feature specs required for every user-facing behavior.

**Organization**: Tasks grouped by user story for independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no shared state)
- **[Story]**: Which user story this task belongs to

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Model and route foundations that unblock all user stories.

- [X] T001 Add `:uploading` (-1) to `Subject` status enum in `app/models/subject.rb`
- [X] T002 Add `optional: true` to `belongs_to :exam_session` in `app/models/subject.rb`
- [X] T003 Add `scope :visible` (excludes `:uploading`) to `app/models/subject.rb`
- [X] T003b [P] Add `unless: :uploading?` guard to `validates :specialty, presence: true` in `app/models/subject.rb` — without this, `Subject.create!(status: :uploading)` with no specialty raises `ActiveRecord::RecordInvalid` and breaks the entire upload flow (C1)
- [X] T003c Migration `allow_null_specialty_on_subjects` — `subjects.specialty` had `null: false, default: 0`; :uploading subjects need nil specialty. Migration: `change_column_null + change_column_default`. Applied ✅
- [X] T004 Add `resource :validation, only: [:show, :update], module: "subjects"` route inside `resources :subjects` in `config/routes.rb`
- [X] T005 Create `app/controllers/teacher/subjects/validations_controller.rb` skeleton (before_action, empty show/update)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Services and specs that US1/US2/US3 all depend on.

**⚠️ CRITICAL**: All user story work requires these services to be in place.

- [X] T006 Write failing unit spec for `MapExtractedMetadata` in `spec/services/map_extracted_metadata_spec.rb` (coercion table: all 6 fields, valid values, invalid → nil, nil input)
- [X] T007 Implement `MapExtractedMetadata` service in `app/services/map_extracted_metadata.rb` — make T006 green
- [X] T008 Write failing unit spec for `MatchExamSession` in `spec/services/match_exam_session_spec.rb` (found, not found, case-insensitive title, cross-teacher isolation, nil title/year → nil)
- [X] T009 Implement `MatchExamSession` service in `app/services/match_exam_session.rb` (ILIKE on title, exact year, owner-scoped) — make T008 green
- [X] T010 Write failing model spec for `Subject` in `spec/models/subject_spec.rb`: (1) status `:uploading` exists, (2) `optional: true` allows nil exam_session, (3) `Subject.new(status: :uploading)` is valid without specialty, (4) `Subject.new` without status is invalid without specialty
- [X] T011 Verify T010 passes (model changes from Phase 1 — T001/T002/T003b — should make it green; fix if not)

**Checkpoint**: Services green, model spec green — user story phases can begin.

---

## Phase 3: User Story 1 — Upload PDFs et auto-remplissage (Priority: P1) 🎯 MVP

**Goal**: Teacher uploads 2 PDFs → extraction runs → validation form pre-fills all metadata → teacher confirms → subject created in `:draft`.

**Independent Test**: A teacher can create a complete subject by uploading two PDFs and clicking "Valider" without manually entering any metadata.

### Specs (TDD — write first, verify failing before implementation)

- [X] T012 [US1] Write failing Capybara feature spec: upload 2 PDFs → redirect to show → extraction done → "Proceed to validation" button appears → click → validation form pre-filled → submit → subject in `:draft` state in `spec/features/teacher/upload_pdfs_and_validate_subject_spec.rb`
- [X] T013 [P] [US1] Write failing Capybara feature spec: single PDF upload → error displayed in `spec/features/teacher/upload_pdfs_and_validate_subject_spec.rb`

### Implementation

- [X] T014 [US1] Rewrite `Teacher::SubjectsController#new` view `app/views/teacher/subjects/new.html.erb` — remove all metadata fields, keep only `subject_pdf` and `correction_pdf` file inputs + submit
- [X] T015 [US1] Rewrite `Teacher::SubjectsController#create` in `app/controllers/teacher/subjects_controller.rb` — permit only `[:subject_pdf, :correction_pdf]`; create `Subject(status: :uploading, owner: current_teacher)`; delete `assign_or_create_exam_session` and `session_params` private methods
- [X] T015b [US1] Update `BuildExtractionPrompt` in `app/services/build_extraction_prompt.rb` — nil specialty fallback (C3)
- [X] T016 [US1] Guard `PersistExtractedData#call` for `:uploading` subjects (C2)
- [X] T017 [US1] Update `app/views/teacher/subjects/show.html.erb` — meta-refresh polling when pending/processing, "Valider le sujet" button when done, error banner when failed
- [X] T018 [US1] Implement `Teacher::Subjects::ValidationsController#show`
- [X] T019 [US1] Create validation form view `app/views/teacher/subjects/validations/show.html.erb`
- [X] T020 [US1] Implement `Teacher::Subjects::ValidationsController#update`
- [X] T021 [US1] Update `Teacher::SubjectsController#index` — split `@pending_subjects` / `@subjects` (G1)

**Checkpoint**: US1 feature spec green. Teacher can upload → validate → create subject with pre-filled metadata, zero manual input in nominal case.

---

## Phase 4: User Story 2 — Rattachement à une ExamSession existante (Priority: P2)

**Goal**: When extraction returns title+year matching an existing ExamSession, validation form shows a notice with "Rattacher / Créer nouvelle" choice.

**Independent Test**: Upload a subject whose extraction returns title+year matching an existing ExamSession → form shows attachment notice with two choices → both paths create the subject correctly.

### Specs (TDD)

- [X] T022 [US2] Write failing Capybara feature spec: extraction matches existing session → notice displayed → "Rattacher" → subject linked in `spec/features/teacher/attach_to_existing_exam_session_spec.rb`
- [X] T023 [P] [US2] Write failing Capybara feature spec: "Créer une nouvelle session" path → new ExamSession created in `spec/features/teacher/attach_to_existing_exam_session_spec.rb`

### Implementation

- [X] T024 [US2] Update `app/views/teacher/subjects/validation/show.html.erb` — add conditional notice block when `@existing_session` is present: display session title, radio/hidden field `exam_session_choice` ("attach" vs "create"), hidden `exam_session_id` field
- [X] T025 [US2] Update `Teacher::Subjects::ValidationController#update` in `app/controllers/teacher/subjects/validation_controller.rb` — handle `exam_session_choice == "attach"` branch: look up existing session by `exam_session_id`, assign to subject instead of building new one

**Checkpoint**: US1 + US2 both green. ExamSession deduplication fully functional.

---

## Phase 5: User Story 3 — Gestion erreurs et métadonnées partielles (Priority: P2)

**Goal**: When extraction fails partially or fully, validation form still appears — available fields pre-filled, missing fields empty with "non détecté" indication.

**Independent Test**: Simulate extraction with partial metadata → form displays with available fields pre-filled and missing fields empty with "non détecté". Full failure → form fully empty with error message.

### Specs (TDD)

- [X] T026 [US3] Write failing Capybara feature spec: partial metadata (region nil) → form shows with partial pre-fill + "non détecté" on region in `spec/features/teacher/partial_extraction_fallback_spec.rb`
- [X] T027 [P] [US3] Write failing Capybara feature spec: full extraction failure → form shows fully empty + error message in `spec/features/teacher/partial_extraction_fallback_spec.rb`

### Implementation

- [X] T028 [US3] Update `app/views/teacher/subjects/validation/show.html.erb` — add "non détecté" visual hint (e.g. placeholder text) on each field when the corresponding `@metadata[:field]` value is nil; add error banner when `@extraction_failed == true`
- [X] T029 [US3] Verify `Teacher::Subjects::ValidationController#show` already handles nil gracefully (MapExtractedMetadata returns all-nil on failed/empty raw_json); add explicit guard if `raw_json` is nil (extraction_job missing or failed before writing raw_json)

**Checkpoint**: US1 + US2 + US3 all green. No teacher ever blocked by extraction failure.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Cleanup, edge cases, cleanup rake task.

- [X] T030 [P] Write rake task `subjects:cleanup_uploading` in `lib/tasks/subjects.rake` — soft-delete (set `discarded_at`) all subjects in `:uploading` status older than 24h
- [X] T031 [P] Delete `app/views/teacher/subjects/_form.html.erb` if it exists (FR-009) — verify no other view references it (`grep -r "_form" app/views/teacher/subjects/`); confirm no metadata entry point survives in the subjects namespace
- [X] T032 [P] Update `Subject` model validations in `app/models/subject.rb` — ensure `required_files_attached` validation does not run for `:uploading` subjects with no specialty yet (guard by status)
- [X] T033 Run full RSpec suite and fix any regressions: `bin/rspec`
- [X] T034 Verify route helpers via `bin/rails routes | grep validation` — confirm no conflicts between subjects/validation and questions/validation routes

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies — start immediately
- **Phase 2 (Foundational)**: Depends on Phase 1 — BLOCKS all user stories
- **Phase 3 (US1)**: Depends on Phase 2 — 🎯 MVP increment
- **Phase 4 (US2)**: Depends on Phase 3 (reuses validation form + controller)
- **Phase 5 (US3)**: Depends on Phase 3 (extends validation form)
- **Phase 6 (Polish)**: Depends on Phases 3/4/5

### Within Each User Story

- Spec tasks written first (TDD) and verified failing before implementation
- Services (T007, T009) before controllers (T018, T020) before views (T019)
- `show` action (T018) before `update` action (T020)
- Upload form/controller (T014, T015) before show polling (T017) before validation form (T018, T019)

### Parallel Opportunities

Within Phase 2: T006+T008 can run in parallel (different service files).
Within Phase 3 specs: T012+T013 can run in parallel.
Within Phase 4 specs: T022+T023 can run in parallel.
Within Phase 5 specs: T026+T027 can run in parallel.
Phase 6: T030, T031, T032 can all run in parallel.

---

## Parallel Example: Phase 2

```
# Parallel spec writing:
Task T006: "Write failing unit spec for MapExtractedMetadata in spec/services/map_extracted_metadata_spec.rb"
Task T008: "Write failing unit spec for MatchExamSession in spec/services/match_exam_session_spec.rb"

# Then parallel implementation:
Task T007: "Implement MapExtractedMetadata in app/services/map_extracted_metadata.rb"
Task T009: "Implement MatchExamSession in app/services/match_exam_session.rb"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Phase 1: Setup — model + route changes
2. Phase 2: Foundational — services + model specs
3. Phase 3: US1 — upload form, extraction polling, validation form (full flow)
4. **STOP and VALIDATE**: `bin/rspec spec/features/teacher/upload_pdfs_and_validate_subject_spec.rb`
5. Ship US1 — already covers the P1 success criterion (SC-001, SC-002, SC-003 partial)

### Incremental Delivery

1. Phases 1+2 → Foundation ready
2. Phase 3 (US1) → Core workflow functional → MVP ✅
3. Phase 4 (US2) → Session deduplication (SC-004)
4. Phase 5 (US3) → Partial failure handling (SC-003 complete)
5. Phase 6 → Cleanup + hardening

---

## Notes

- **T016 guard scope** (C2): `PersistExtractedData` has 5 exam_session-dependent paths + 1 status update — all must be skipped for `:uploading` subjects. Only `code`, `specific_presentation`, and specific Parts/Questions survive. See T016 for the exact list.
- **T015b** (C3): `BuildExtractionPrompt` uses `specialty` to filter which parts to extract. With nil specialty, use a generic fallback message; Claude should return all parts. The validation form (T019) then maps the extracted specialty to one of the 4 enum values.
- **T003b** (C1): Without the `unless: :uploading?` guard on specialty validation, `Subject.create!` in T015 raises immediately — the entire flow collapses silently.
- **`resource :validation` route** (I1): `module: "subjects"` vs `module: "questions"` avoids collision. Verify with `bin/rails routes | grep validation` after T004.
- **Index split** (G1): `@pending_subjects` (uploading) shown separately from `@subjects` (visible). The teacher can always find and return to an in-progress upload.
- **Abandonment cleanup** (T030): Not wired to Sidekiq in MVP — run as rake task or cron. Post-MVP: Sidekiq scheduled job.
- **Constitution IV (TDD)**: All spec tasks (T006, T008, T010, T012, T013, T022, T023, T026, T027) must be written and verified failing before the corresponding implementation task begins.
