# Quickstart: Tuteur guidé — Micro-tâches de repérage

## Prerequisites

- Ruby 3.3+, Rails 8.1.3
- PostgreSQL (Neon) running
- Redis running (for Sidekiq/ActionCable)
- `bin/dev` starts Rails + Sidekiq + Tailwind

## Setup

```bash
git checkout 011-guided-tutor-spotting
bundle install
bin/rails db:migrate
bin/dev
```

## Manual Test Flow

1. Login as teacher, create a classroom + student
2. Upload a subject PDF, run extraction, validate at least one question
3. Publish the subject, assign to classroom
4. Login as student (via access code)
5. Go to Settings → configure API key + select "Tutorat IA" mode
6. Navigate to the subject → mise en situation page
7. Click "Commencer les questions"
8. On the question page: the spotting card should appear
9. Select task type + data sources → click [Vérifier]
10. Check feedback → [Voir la correction] should now be visible
11. After correction: click {expliquer la correction} → chat opens

## Key Files to Know

| File | Role |
|---|---|
| `app/controllers/student/tutor_controller.rb` | Spotting actions |
| `app/models/student_session.rb` | `tutor_state` JSONB helpers |
| `app/views/student/tutor/_spotting_card.html.erb` | Encart UI |
| `app/javascript/controllers/spotting_controller.js` | Client interaction |
| `app/services/build_tutor_prompt.rb` | AI prompt with spotting context |
