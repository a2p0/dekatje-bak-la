# Tasks: Restructuration du JSON d'extraction

**Input**: Design documents from `/specs/020-extraction-json-restructure/`
**Prerequisites**: plan.md, spec.md, data-model.md, research.md

**Tests**: TDD obligatoire (constitution principe IV). Specs mises à jour AVANT le code.

**Organization**: Tasks grouped by user story for independent implementation.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story (US1, US2, US3)

---

## Phase 1: Setup

**Purpose**: Migrations de base de données

- [ ] T001 Migration: rename `exam_type` → `exam` and `presentation_text` → `common_presentation` on exam_sessions, add `variante` column (integer, default: 0) in `db/migrate/XXX_restructure_exam_sessions.rb`
- [ ] T002 Migration: rename `presentation_text` → `specific_presentation`, add `code` column (string, not null), rename enum value `drom_com` → `reunion` on subjects in `db/migrate/XXX_restructure_subjects.rb`
- [ ] T003 Migration: remove redundant columns (`title`, `year`, `exam_type`, `region`) from subjects in `db/migrate/XXX_remove_redundant_subject_columns.rb`
- [ ] T004 Migration: rename enum value `drom_com` → `reunion` on exam_sessions in `db/migrate/XXX_rename_drom_com_to_reunion.rb`
- [ ] T005 Run migrations and verify `db:rollback` works for each

---

## Phase 2: Foundational (Models & Factories)

**Purpose**: Adapter les modèles et factories au nouveau schéma. BLOQUE toutes les user stories.

- [ ] T006 [P] Update `app/models/exam_session.rb`: rename enum `exam_type` → `exam`, rename enum value `drom_com` → `reunion`, add enum `variante` (normale: 0, remplacement: 1)
- [ ] T007 [P] Update `app/models/subject.rb`: remove enums `exam_type`/`region`, remove validations on `title`/`year`/`exam_type`/`region`, add `delegate :title, :year, :exam, :region, :common_presentation, :variante, to: :exam_session`, make `exam_session` required, add validation on `code` presence
- [ ] T008 [P] Update `spec/factories/exam_sessions.rb`: add `variante`, rename `exam_type` → `exam`, rename `presentation_text` → `common_presentation`
- [ ] T009 [P] Update `spec/factories/subjects.rb`: remove `title`/`year`/`exam_type`/`region`, rename `presentation_text` → `specific_presentation`, add `code`, ensure `exam_session` association
- [ ] T010 [P] Update `spec/factories/parts.rb`: verify compatibility (parts reference subject or exam_session)
- [ ] T011 Grep all references to `subject.title`, `subject.year`, `subject.exam_type`, `subject.region`, `subject.presentation_text`, `exam_session.exam_type`, `exam_session.presentation_text` across views, controllers, services, specs — list all files needing updates
- [ ] T012 Update all view files referencing renamed columns (delegates handle most, but forms and explicit column access need fixing)
- [ ] T013 Update all controller files referencing renamed columns in `app/controllers/`
- [ ] T014 Run full spec suite to verify foundational changes don't break existing tests

**Checkpoint**: Models, factories, and all references updated. All existing specs pass.

---

## Phase 3: User Story 1 — Deux mises en situation distinctes (Priority: P1) 🎯 MVP

**Goal**: Le prompt produit `common_presentation` + `specific_presentation` et la persistence les stocke correctement.

**Independent Test**: Extraction d'un sujet BAC → JSON contient les deux présentations → persistence les stocke sur ExamSession et Subject respectivement.

### Specs for User Story 1

- [ ] T015 [P] [US1] Update `spec/services/build_extraction_prompt_spec.rb`: assert `common_presentation` and `specific_presentation` in system prompt, assert `presentation` key is absent
- [ ] T016 [P] [US1] Update `spec/services/persist_extracted_data_spec.rb`: update fixture JSON with `common_presentation`/`specific_presentation`, assert ExamSession gets `common_presentation`, assert Subject gets `specific_presentation`

### Implementation for User Story 1

- [ ] T017 [US1] Update `app/services/build_extraction_prompt.rb`: replace `presentation` with `common_presentation` + `specific_presentation` in JSON schema, add instructions for identifying both presentations in the PDF, update few-shot example
- [ ] T018 [US1] Update `app/services/persist_extracted_data.rb`: read `data["common_presentation"]` → `exam_session.common_presentation`, read `data["specific_presentation"]` → `subject.specific_presentation` via `update_column`
- [ ] T019 [US1] Verify specs T015 and T016 pass

**Checkpoint**: Extraction produces two presentations, persistence stores them correctly.

---

## Phase 4: User Story 2 — Code sujet extrait automatiquement (Priority: P2)

**Goal**: Le prompt extrait le code sujet et les métadonnées dérivées (region, variante).

**Independent Test**: JSON contient `metadata.code` correct, `metadata.region` et `metadata.variante` cohérents avec le code.

### Specs for User Story 2

- [ ] T020 [P] [US2] Update `spec/services/build_extraction_prompt_spec.rb`: assert `metadata.code`, `metadata.region`, `metadata.variante` in system prompt
- [ ] T021 [P] [US2] Update `spec/services/persist_extracted_data_spec.rb`: assert `subject.code` is set from `metadata.code`, assert `exam_session.variante` is set

### Implementation for User Story 2

- [ ] T022 [US2] Update `app/services/build_extraction_prompt.rb`: add `code` (OBLIGATOIRE), `region`, `variante` to metadata schema, add code format explanation (YY-SSSSXXRRN) and mapping tables for region/variante
- [ ] T023 [US2] Update `app/services/persist_extracted_data.rb`: read `metadata["code"]` → `subject.code` (raise if blank), read `metadata["variante"]` → `exam_session.variante`, read `metadata["region"]` → `exam_session.region`
- [ ] T024 [US2] Verify specs T020 and T021 pass

**Checkpoint**: Code sujet extrait et stocké, region/variante déduits et persistés.

---

## Phase 5: User Story 3 — Métadonnées renommées (Priority: P3)

**Goal**: Le JSON utilise `exam` au lieu de `exam_type`, `year` en string.

**Independent Test**: JSON contient `metadata.exam` (pas `exam_type`), `metadata.year` est une string.

### Specs for User Story 3

- [ ] T025 [P] [US3] Update `spec/services/build_extraction_prompt_spec.rb`: assert `metadata.exam` (not `exam_type`), assert `metadata.year` is documented as string
- [ ] T026 [P] [US3] Update `spec/services/persist_extracted_data_spec.rb`: assert mapping `exam` → `exam_session.exam`

### Implementation for User Story 3

- [ ] T027 [US3] Update `app/services/build_extraction_prompt.rb`: rename `exam_type` → `exam` in metadata schema and few-shot, document `year` as string
- [ ] T028 [US3] Update `app/services/persist_extracted_data.rb`: map `metadata["exam"]` → `exam_session.exam`
- [ ] T029 [US3] Verify specs T025 and T026 pass

**Checkpoint**: Metadata uses consistent naming, all specs pass.

---

## Phase 6: Polish & Cross-Cutting

**Purpose**: Seed, validation finale, cleanup

- [ ] T030 Regenerate extraction JSON: run extraction with new prompt on CIME subject → save to `db/seeds/development/claude_extraction.json`
- [ ] T031 Update `db/seeds/development.rb`: adapt to new JSON format (`common_presentation`, `specific_presentation`, new metadata fields)
- [ ] T032 Verify `bin/rails db:seed:replant` works with new seed
- [ ] T033 Run full spec suite — all specs pass
- [ ] T034 Push branch, create PR, verify CI green

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies — migrations first
- **Phase 2 (Foundational)**: Depends on Phase 1 — BLOCKS all user stories
- **Phase 3 (US1)**: Depends on Phase 2
- **Phase 4 (US2)**: Depends on Phase 2 (can run parallel with US1)
- **Phase 5 (US3)**: Depends on Phase 2 (can run parallel with US1/US2)
- **Phase 6 (Polish)**: Depends on all user stories complete

### Within Each User Story

- Specs written FIRST (TDD)
- Implementation to make specs pass
- Verification checkpoint

### Parallel Opportunities

- T006, T007, T008, T009, T010 can all run in parallel (different files)
- T015, T016 can run in parallel (different spec files)
- US1, US2, US3 implementation can theoretically run in parallel but share prompt/persistence files — sequential recommended for this feature
- T020, T021 can run in parallel
- T025, T026 can run in parallel

---

## Implementation Strategy

### Sequential Approach (Recommended)

Since US1, US2, US3 all modify the same files (`build_extraction_prompt.rb`, `persist_extracted_data.rb`), sequential execution is cleaner:

1. Phase 1: Migrations → Phase 2: Models/Factories/References
2. Phase 3: US1 (presentations) — core change
3. Phase 4: US2 (code/region/variante) — additive
4. Phase 5: US3 (renaming) — cleanup
5. Phase 6: Seed regeneration + validation

### MVP

Phase 1 + Phase 2 + Phase 3 (US1) = minimum viable: two presentations separated.

---

## Notes

- Constitution principle IV: TDD mandatory — specs before code
- Constitution principle VI: CI validation, never run feature specs locally
- All prompt changes require re-testing extraction on real PDF (Phase 6, T030)
- Commit after each task or logical group
