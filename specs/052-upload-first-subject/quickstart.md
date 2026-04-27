# Quickstart: Upload-First Subject Creation

**Branch**: `052-upload-first-subject`

## Key Implementation Order

1. **Model first** (TDD): add `:uploading` to `Subject.statuses`, add `optional: true` to `belongs_to :exam_session` → write unit spec first, then change model
2. **Services**: `MapExtractedMetadata` (pure, easy to TDD) → `MatchExamSession`
3. **Controller `create`**: simplify to upload-only (remove session creation logic)
4. **Show page**: add extraction status polling (Turbo Frame)
5. **ValidationController**: show + update actions
6. **Views**: new upload form, validation form
7. **Cleanup**: remove old form metadata fields, `assign_or_create_exam_session`, `session_params`
8. **Rake task**: `subjects:cleanup_uploading`

## Critical Notes

- `belongs_to :exam_session, optional: true` is a model-only change (no migration — `exam_session_id` is already nullable in schema)
- `status: :uploading` uses value `-1` — no migration needed (Rails integer enum is Ruby-side)
- After `subjects_controller.rb#create`, ExtractionJob is created with `exam_session_id: nil` — `PersistExtractedData` calls `exam_session.update!` which would crash. Must guard: skip metadata persistence for `:uploading` subjects (the validation form handles this)
- The `name :validation` route conflict (questions vs subjects modules) is resolved by the `module:` param — test routes with `bin/rails routes | grep validation`

## Test Commands

```bash
bin/rspec spec/models/subject_spec.rb                          # model changes
bin/rspec spec/services/map_extracted_metadata_spec.rb         # coercion table
bin/rspec spec/services/match_exam_session_spec.rb             # lookup service
bin/rspec spec/features/teacher/upload_pdfs_and_validate_subject_spec.rb
bin/rspec spec/features/teacher/attach_to_existing_exam_session_spec.rb
bin/rspec spec/features/teacher/partial_extraction_fallback_spec.rb
```
