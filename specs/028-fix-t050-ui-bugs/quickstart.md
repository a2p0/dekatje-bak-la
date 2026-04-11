# Quickstart: Fix T050 UI Bugs

## Setup

```bash
git checkout 028-fix-t050-ui-bugs
bin/dev  # starts PostgreSQL, Redis, Rails, Sidekiq, Tailwind
```

## Key files

- `app/views/student/questions/show.html.erb` — question page layout
- `app/views/student/questions/_correction.html.erb` — correction partial
- `app/controllers/student/subjects_controller.rb` — subject navigation logic
- `app/helpers/student/data_hints_helper.rb` — NEW: source label + badge color helper

## Test

```bash
bundle exec rspec spec/helpers/student/data_hints_helper_spec.rb
bundle exec rspec spec/features/student_question_navigation_spec.rb
bundle exec rspec spec/features/student/subject_workflow_spec.rb
```
