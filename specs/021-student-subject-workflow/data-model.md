# Data Model: Workflow sujet complet élève

**Date**: 2026-04-08

## Entities Modified

### StudentSession (existing — no migration)

**Modified JSONB field: `progression`**

Current structure:
```json
{
  "42": { "seen": true, "answered": false },
  "43": { "seen": true, "answered": true }
}
```

New structure (additive):
```json
{
  "42": { "seen": true, "answered": false },
  "43": { "seen": true, "answered": true },
  "parts_completed": [3, 7],
  "specific_presentation_seen": true,
  "completed_at": "2026-04-08T14:30:00Z"
}
```

**New keys**:
| Key | Type | Description |
|-----|------|-------------|
| `parts_completed` | Array<Integer> | IDs of parts where student clicked "Fin de la partie" |
| `specific_presentation_seen` | Boolean | True after student has seen the specific mise en situation |
| `completed_at` | String (ISO8601) | Timestamp when subject was explicitly terminated |

**New methods**:
| Method | Signature | Description |
|--------|-----------|-------------|
| `mark_part_completed!` | `(part_id) -> void` | Adds part_id to `parts_completed`, saves |
| `part_completed?` | `(part_id) -> Boolean` | Checks if part_id is in `parts_completed` |
| `all_parts_completed?` | `() -> Boolean` | True if all filtered parts are in `parts_completed` |
| `subject_completed?` | `() -> Boolean` | True if `completed_at` is set |
| `mark_subject_completed!` | `() -> void` | Sets `completed_at` to current time, saves |
| `specific_presentation_seen?` | `() -> Boolean` | Checks flag in progression |
| `mark_specific_presentation_seen!` | `() -> void` | Sets flag, saves |
| `unanswered_questions` | `() -> Array<Question>` | Returns questions from filtered parts not yet answered |

## Entities Unchanged (used as-is)

### Part
- `section_type` (enum: common/specific) — used for grouping in view
- `objective_text` (text) — displayed under part title
- `number`, `title`, `position` — display and ordering

### Subject
- `specific_presentation` (text, via ExamSession) — displayed as intermediate screen
- `common_presentation` (text, delegated) — already displayed

### ExamSession
- `common_parts` association — already used for filtered_parts

## State Transitions

```
[Subject entry]
    │
    ├─ scope_selected? = false ──> [Scope selection screen]
    │                                    │
    │                                    v set_scope → scope_selected = true
    │
    ├─ subject_completed? ──> [Parts list - relecture mode]
    │
    ├─ all_parts_completed? + unanswered questions ──> [Unanswered questions page]
    │
    ├─ all_parts_completed? + all answered ──> [Completion page "Bravo !!"]
    │
    ├─ first visit (no progress) ──> [Mise en situation + parts list]
    │
    ├─ specific part next + !specific_presentation_seen? ──> [Specific presentation]
    │
    └─ default ──> [Redirect to first undone question]

[Question navigation]
    │
    ├─ last question in part ──> [Button: "Fin de la partie"]
    │                                │
    │                                v complete_part → mark_part_completed!
    │                                      → redirect to subject#show
    │
    ├─ from=review param ──> [Button: "Question suivante" → unanswered page]
    │
    └─ default ──> [Button: "Question suivante" → next question]

[Subject completion]
    │
    ├─ "Terminer le sujet" button ──> mark_subject_completed! → completion page
    │
    └─ All questions answered after all parts completed ──> completion page
```

## Routes (new)

| Method | Path | Action | Description |
|--------|------|--------|-------------|
| PATCH | `/:access_code/subjects/:id/complete_part/:part_id` | `student/subjects#complete_part` | Mark part as completed |
| PATCH | `/:access_code/subjects/:id/complete` | `student/subjects#complete` | Mark subject as completed |
