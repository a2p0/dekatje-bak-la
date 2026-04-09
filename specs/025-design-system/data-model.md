# Data Model: 025 — Design System

No schema changes. No new models, migrations, or database modifications.

This feature is purely visual — it modifies views, components, CSS, and JavaScript controllers.

## Existing Models (unchanged)

All models referenced by views remain unchanged:
- `Subject`, `Part`, `Question`, `Answer` — displayed in student views
- `Student`, `StudentSession`, `Conversation` — used for session state and chat
- `Classroom` — displayed on subjects index
- `TechnicalDocument` — linked in sidebar
