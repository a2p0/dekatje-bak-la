# Quickstart: Workflow sujet complet élève

**Branch**: `021-student-subject-workflow`

## Setup

```bash
git checkout 021-student-subject-workflow
bin/dev  # Starts Rails + Redis + PostgreSQL
```

No migration needed for this feature.

## Dev Seed

The development seed (`bin/rails db:seed`) creates a subject with common and specific parts. Use this to test the full workflow.

## Manual Testing

1. Login as student: `http://localhost:3000/{access_code}` (e.g., `terminale-sin-2026`)
2. Select a published subject
3. Choose "Sujet complet" scope
4. Verify: parts grouped by COMMUNE / SPÉCIFIQUE with objectives
5. Navigate through questions → verify "Fin de la partie" on last question
6. After both parts: verify unanswered questions page (if any skipped)
7. Click "Terminer le sujet" → verify "Bravo !!" page
8. Re-enter subject → verify relecture mode (no re-trigger of completion)

## Test Execution

```bash
# Unit tests
bundle exec rspec spec/models/student_session_spec.rb

# Request tests
bundle exec rspec spec/requests/student/subjects_spec.rb

# Feature tests (CI recommended — slow locally)
bundle exec rspec spec/features/student/subject_workflow_spec.rb
```
