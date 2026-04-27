# Research: Upload-First Subject Creation Workflow

**Branch**: `052-upload-first-subject` | **Date**: 2026-04-27

## R-1: Architecture Pattern

**Decision**: Pattern A — extend `Subject` with `:uploading` status (-1)

**Why**: `ExtractionJob belongs_to :subject` is a required FK; PDFs live on `Subject` via ActiveStorage. Pattern B (new model) would require attachment transfer + a migration + a new controller. Pattern A needs zero new columns (just a model-level enum value) and `optional: true` on `belongs_to :exam_session`.

**Rationale**: `subjects.exam_session_id` is already nullable in `db/schema.rb`. `belongs_to :exam_session` in `subject.rb` has no `optional: true` — this one-line change unblocks the intermediary `:uploading` state.

**Alternatives considered**: Pattern B (SubjectDraft model) — rejected: adds ~40% more code, new migration, new model, attachment transfer logic, with no functional benefit for MVP.

**Abandonment cleanup**: Orphan `:uploading` subjects (teacher abandoned after upload, before validation) → soft-deleted by a rake task `subjects:cleanup_uploading` (subjects older than 24h in `:uploading` state). MVP: rake task run daily. Post-MVP: Sidekiq scheduled job.

## R-2: ExamSession Lookup Criteria

**Decision**: Match by `title` (ILIKE, trimmed) + `year` (exact string), scoped to `current_teacher.exam_sessions` (`owner_id`).

**Why**: Spec says "même titre + même année". Teacher-scoped prevents cross-teacher collisions. Case-insensitive prevents near-duplicates from different Claude extraction runs.

**Alternatives considered**: Including `region` in match key — rejected. Same exam in two regions shares common parts under one session; adding `region` would prevent legitimate session reuse.

## R-3: Enum Coercion Table

`MapExtractedMetadata` normalizes Claude's raw string output:

| Field | Accepted raw values | Rails enum symbol | Invalid → |
|-------|--------------------|--------------------|-----------|
| `specialty` | "SIN", "ITEC", "EE", "AC" (case-insensitive) | `:sin`, `:itec`, `:ee`, `:ac` | `nil` (field empty) |
| `exam` | "bac", "bts", "autre" (case-insensitive) | `:bac`, `:bts`, `:autre` | `nil` |
| `region` | "metropole", "reunion", "polynesie", "candidat_libre" (case-insensitive) | symbol | `nil` |
| `variante` | "normale", "remplacement" (case-insensitive) | symbol | `nil` (ExamSession defaults to `normale`) |
| `year` | any string | string as-is | `nil` |
| `title` | any string | string as-is | `nil` |

Note: `tronc_commun` is not accessible via this workflow (per FR-004 and spec assumptions).

## R-4: Controller Shape

**Decision**: Nested resource `resource :validation, only: [:show, :update], module: "subjects"` under `:subjects`.

Routes:
```
GET  /teacher/subjects/:id/validation  → Teacher::Subjects::ValidationController#show
PATCH /teacher/subjects/:id/validation → Teacher::Subjects::ValidationController#update
```

**Why**: Matches existing patterns in this app (`publication`, `assignment`, `extraction` all use nested resource controllers in `teacher/subjects/`).

## R-5: Polling Strategy

**Decision**: Turbo Frame polling on `teacher_subject_path(@subject)` (existing show page).

The show page checks `extraction_job.status`:
- `pending/processing` → spinner with `<turbo-frame>` polling every 3s
- `done` → auto-redirect to validation path (or "Proceed to validation" button)
- `failed` → error message + retry link

**Why**: No ActionCable needed for a single-teacher flow. Turbo polling is already the app's pattern. Simpler.

## R-6: Deletion Scope (FR-009)

Artifacts removed (not toggled):
- Metadata fields from `new.html.erb` (title, year, exam, specialty, region) 
- ExamSession dropdown from `new.html.erb`
- `assign_or_create_exam_session` private method in `SubjectsController`
- `session_params` private method in `SubjectsController`

These are replaced by the validation step (ValidationController).

## R-7: Status Enum Value for :uploading

**Decision**: Use value `-1` for `:uploading`.

**Why**: Avoids re-numbering existing production values (draft=0, pending_validation=1, published=2, archived=3). Rails integer enum stores the integer value, so -1 is fully valid. No migration needed — only the model enum declaration changes.

Verification: no production record should have `status = -1` (confirmed by reading schema; no existing migration sets this value).
