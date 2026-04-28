# Implementation Plan: Upload-First Subject Creation Workflow

**Branch**: `052-upload-first-subject` | **Date**: 2026-04-27 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/052-upload-first-subject/spec.md`

## Summary

Replace the current subject creation form (metadata first, then upload) with an upload-first workflow: the teacher uploads two PDFs, extraction runs asynchronously, then a validation form pre-fills all metadata from the extraction result. The teacher confirms or corrects, then creates the subject.

Architectural approach: **Pattern A — Lifecycle extension on Subject**. A `Subject` record is created immediately on upload (status `:uploading`) with PDFs attached and `exam_session_id: null`. Extraction runs on this record. The validation step fills in metadata and transitions to `:draft`. This reuses `ExtractionJob belongs_to :subject` and `ActiveStorage` on `Subject` without a new model.

## Technical Context

**Language/Version**: Ruby 3.3+ / Rails 8.1.3  
**Primary Dependencies**: Hotwire (Turbo Streams), ActiveStorage, Sidekiq, Devise (teacher auth), RSpec + FactoryBot + Capybara  
**Storage**: PostgreSQL via Neon (subjects.exam_session_id already nullable in schema), ActiveStorage for PDFs  
**Testing**: RSpec unit + Capybara feature specs — mandatory per constitution  
**Target Platform**: Linux server (Coolify), fullstack Rails  
**Project Type**: Web application (Rails fullstack)  
**Performance Goals**: Upload + extraction + validation total < 2 minutes (SC-001)  
**Constraints**: `belongs_to :exam_session` must become `optional: true` on `Subject`; ExamSession lookup is teacher-scoped (`owner_id`)  
**Scale/Scope**: Solo teacher flow, one subject created at a time

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Gate | Status | Notes |
|------|--------|-------|
| I. Fullstack Rails — Hotwire Only | PASS | No SPA; Turbo Streams for extraction status polling |
| II. RGPD & mineurs | PASS | Teacher-only feature; no student data involved |
| III. Security | PASS | Teacher auth via Devise; no new API key exposure |
| IV. Testing (NON-NEGOTIABLE) | PASS | 3 feature specs (one per user story) + unit specs for new services required |
| V. Performance & Simplicity | PASS | Pattern A avoids a new model; soft-delete on abandoned `:uploading` subjects instead of hard delete |
| VI. Development Workflow | PASS | Branch exists; speckit workflow followed |

**No constitution violations.** Complexity tracking section skipped.

## Project Structure

### Documentation (this feature)

```text
specs/052-upload-first-subject/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
└── tasks.md             # Phase 2 output (/speckit.tasks)
```

### Source Code (repository root)

```text
app/
├── controllers/teacher/
│   ├── subjects_controller.rb       # new, create, show, destroy: extend; add validate action
│   └── subjects/
│       └── validation_controller.rb # GET validate (show form) + PATCH update (confirm + create session)
├── models/
│   └── subject.rb                   # Add :uploading status; optional: true on exam_session
├── services/
│   ├── map_extracted_metadata.rb    # NEW — maps raw_json metadata to typed attributes
│   ├── match_exam_session.rb        # NEW — lookup by title+year+owner, case-insensitive
│   └── build_extraction_prompt.rb   # MODIFIED — nil specialty fallback for :uploading subjects
├── views/teacher/subjects/
│   ├── new.html.erb                 # Becomes: only two file fields (upload form)
│   ├── show.html.erb                # Polling Turbo Frame for extraction status
│   └── validate.html.erb            # NEW — validation/confirmation form
└── views/teacher/subjects/validation/
    └── _form.html.erb               # Partial: pre-filled metadata fields

spec/
├── features/teacher/
│   ├── upload_pdfs_and_validate_subject_spec.rb  # US1
│   ├── attach_to_existing_exam_session_spec.rb   # US2
│   └── partial_extraction_fallback_spec.rb       # US3
├── services/
│   ├── map_extracted_metadata_spec.rb
│   └── match_exam_session_spec.rb
└── models/
    └── subject_spec.rb              # :uploading status, optional exam_session

# No migration needed: :uploading = -1 (integer enum, Ruby-side only; exam_session_id already nullable)
```

**Structure Decision**: Rails fullstack, single repo. New controller resource `subjects#validate` (GET) and `subjects/validation#update` (PATCH) nested under `:subjects`. Services `MapExtractedMetadata` and `MatchExamSession` introduced per conventions.

---

## Phase 0: Research

### R-1: Pattern A (lifecycle extension) vs Pattern B (new model)

**Decision**: Pattern A — extend `Subject` with `:uploading` status.

**Rationale**:
- `ExtractionJob belongs_to :subject` (required FK). Changing to optional would require migration + model change. Pattern A avoids this.
- `ActiveStorage` attachments live on `Subject`. Transferring them in Pattern B adds complexity and race conditions.
- `subjects.exam_session_id` is already nullable in `db/schema.rb` (no `NOT NULL` constraint). `belongs_to :exam_session` just needs `optional: true` added to the model (no migration needed).
- Pattern A: zero migrations — `:uploading` uses value -1 (safe for integer enum, Ruby-side only) + `optional: true` model change.

**Alternatives considered**: Pattern B (new `SubjectDraft` model) — rejected: new migration, model, controller, and attachment transfer logic add ~40% more code for no functional gain in MVP.

**Abandonment cleanup**: Subjects stuck in `:uploading` (extraction never completed, teacher abandoned) → soft-deleted via a Sidekiq cleanup job scheduled after 24h. In MVP, a rake task `subjects:cleanup_uploading` run daily is sufficient. Orphaned `:uploading` subjects appear in admin but not in teacher's subject list (scope: `kept.where.not(status: :uploading)`).

---

### R-2: ExamSession lookup criteria

**Decision**: Match by `title` (case-insensitive, trimmed) + `year` (exact string), scoped to `current_teacher.exam_sessions`.

**Rationale**:
- Spec says "même titre + même année" — no mention of region/variante in the dedup key. These are details of the *session*, not identifiers.
- Teacher-scoped: a different teacher's "CIME 2024" session must not trigger a match.
- Case-insensitive trim prevents near-duplicate titles from different extraction runs (Claude may capitalize differently).

**Alternatives considered**: Adding `region` to the match key — rejected: over-constraining. If the same exam is organized in two regions, they legitimately share a session for common parts.

---

### R-3: Enum coercion table (metadata strings → Rails enums)

Extraction returns raw strings from Claude. Coercion map (in `MapExtractedMetadata`):

| Field | Raw value examples | Enum value | Invalid → |
|-------|--------------------|------------|-----------|
| `specialty` | "SIN", "ITEC", "EE", "AC", "sin", "itec" | downcased symbol | `nil` (field empty, per FR-004) |
| `exam` | "bac", "bts", "autre", "BAC" | downcased symbol | `nil` |
| `region` | "metropole", "reunion", "polynesie", "candidat_libre" | downcased symbol | `nil` |
| `variante` | "normale", "remplacement" | downcased symbol | `nil` (defaults to `"normale"` since ExamSession.variante defaults to 0) |
| `year` | "2024", "2025" | string as-is | `nil` |
| `title` | any string | string as-is | `nil` |

Invalid/unknown values → field left `nil` (not pre-filled, professor fills manually — per FR-007).

---

### R-4: Controller shape

**Decision**: Extend `Teacher::SubjectsController` with a `validate` action (GET) and add `Teacher::Subjects::ValidationController` with an `update` action (PATCH).

Routes:
```ruby
namespace :teacher do
  resources :subjects, only: [:index, :new, :create, :show, :destroy] do
    resource :validation, only: [:show, :update], module: "subjects"
    # ...existing resources...
  end
end
```

- `GET  /teacher/subjects/:id/validation` → show the validation form (pre-filled)
- `PATCH /teacher/subjects/:id/validation` → confirm, create/attach ExamSession, transition to `:draft`

**Rationale**: Matches existing REST patterns in this app (`publication`, `assignment`, `extraction` all follow this nested resource pattern). The validation form is a RESTful resource on the subject, not a new action on the base controller.

---

### R-5: Polling strategy for extraction status

**Decision**: Turbo Frame polling on the upload confirmation page (`show.html.erb`).

- After `create`, redirect to `teacher_subject_path(@subject)` (existing show page).
- `show.html.erb` already handles `@extraction_job` status. Extend it with:
  - When `extraction_job.pending? || extraction_job.processing?`: show spinner with `<turbo-frame>` polling `src` every 3 seconds.
  - When `extraction_job.done?`: auto-redirect to `teacher_subject_subject_validation_path(@subject)` (or show a "Valider" button).
  - When `extraction_job.failed?`: show error and link to retry extraction.
- No ActionCable needed — Turbo Frame polling is sufficient for a single teacher flow.

---

### R-6: Old form deletion scope (FR-009)

**Deleted artifacts** (not toggled, per constitution):
- `app/views/teacher/subjects/new.html.erb` → replaced entirely (metadata fields removed, only two file inputs remain)
- `app/views/teacher/subjects/_form.html.erb` (if it exists) → deleted
- `Teacher::SubjectsController#assign_or_create_exam_session` private method → deleted
- `session_params` in `Teacher::SubjectsController` → deleted
- ExamSession dropdown in the new upload form → does not appear (selection happens at validation step)

---

## Phase 1: Design & Contracts

### data-model.md (inline)

#### Changes to existing models

**Subject** — `status` enum extended:
```ruby
enum :status, { uploading: -1, draft: 0, pending_validation: 1, published: 2, archived: 3 }
# WARNING: uploading = -1 to avoid reindexing existing values (0-3 in production)
belongs_to :exam_session, optional: true   # add optional: true
```

No new columns on `subjects`. The `exam_session_id` is already nullable.

Migration:
```ruby
# No column change needed — enum is Ruby-side only if integer.
# BUT: currently status is an integer enum. Adding -1 requires no migration
# (integers are stored as-is). Just update model enum declaration.
# VERIFY: confirm the existing subjects do not have status = -1 in production.
```

Actually: Rails integer enum does NOT store text; adding value -1 is safe at the Ruby level. No migration required. The `status` column is already `integer`. ✅

**Subject** — validation flow lifecycle:
```
:uploading → (extraction done) → redirect to validation → (teacher confirms) → :draft
:uploading → (extraction failed) → redirect to validation (empty form + error) → :draft
```

#### New services

**`MapExtractedMetadata`** — pure function, no DB calls:
```ruby
MapExtractedMetadata.call(raw_json) 
# → { title:, year:, exam:, specialty:, region:, variante: }
# All values are valid enum strings or nil. No invalid values passed through.
```

**`MatchExamSession`** — DB lookup:
```ruby
MatchExamSession.call(owner:, title:, year:)
# → ExamSession or nil
# Uses case-insensitive ILIKE on title, exact match on year, scoped to owner
```

#### Contracts

**Route contracts** (REST):

| Method | Path | Action | Auth |
|--------|------|--------|------|
| GET | /teacher/subjects/new | upload form (2 PDF fields only) | teacher |
| POST | /teacher/subjects | create (upload PDFs → start extraction) | teacher |
| GET | /teacher/subjects/:id | show (extraction status polling) | teacher |
| GET | /teacher/subjects/:id/validation | validation form (pre-filled metadata) | teacher |
| PATCH | /teacher/subjects/:id/validation | confirm → create ExamSession → :draft | teacher |

**`Teacher::Subjects::ValidationController#show` — response contract**:

Pre-conditions:
- `@subject.status == :uploading` (extraction may be done or failed)
- `@subject.extraction_job` exists

Outputs:
- `@metadata` = `MapExtractedMetadata.call(extraction_job.raw_json)` (all fields or nil per coercion table)
- `@existing_session` = `MatchExamSession.call(owner: current_teacher, title: @metadata[:title], year: @metadata[:year])` — nil if no match
- `@extraction_failed` = `extraction_job.failed?` — boolean

**`Teacher::Subjects::ValidationController#update` — params contract**:
```ruby
permit(:title, :year, :exam, :region, :variante, :specialty, :exam_session_choice)
# exam_session_choice: "attach" | "create"
```

Post-conditions:
- If `exam_session_choice == "attach"`: `@subject.exam_session = existing_session`
- If `exam_session_choice == "create"` or no existing session: `create ExamSession` from form params
- `@subject.update!(specialty:, status: :draft)`
- Redirect to `teacher_subject_path(@subject)` with success notice

---

### quickstart.md (inline)

**Developer setup for this feature**:

1. Run `bundle exec rails db:migrate` (no migration if enum-1 approach; validate first with `bin/rails c` check)
2. Add `optional: true` to `belongs_to :exam_session` in `app/models/subject.rb`
3. Add `:uploading` to `Subject.statuses` enum
4. Run `bin/rspec spec/models/subject_spec.rb` — should fail on new status tests
5. Implement model change → green
6. Run feature specs: `bin/rspec spec/features/teacher/` (will fail until full implementation)
7. Implement services → run unit specs after each
8. Implement controller/views → run feature specs

---

## Complexity Tracking

No constitution violations. Section skipped.
