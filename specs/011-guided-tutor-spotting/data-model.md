# Data Model: Tuteur guidé — Micro-tâches de repérage

## Modified Entity: StudentSession

**Table**: `student_sessions` (existing)

### New Column

| Column | Type | Default | Null | Description |
|---|---|---|---|---|
| `tutor_state` | jsonb | `{}` | false | État du parcours guidé : repérage par question |

### JSONB Structure: `tutor_state`

```json
{
  "question_states": {
    "<question_id>": {
      "step": "spotting | feedback | skipped",
      "spotting": {
        "task_type_answer": "calculation",
        "task_type_correct": true,
        "sources_answer": ["DT2", "mise_en_situation"],
        "sources_correct": ["DT2", "mise_en_situation"],
        "sources_missed": [],
        "sources_extra": [],
        "completed_at": "2026-04-01T14:30:00Z"
      }
    }
  }
}
```

### State Transitions per Question

```
[new question] → spotting
spotting → feedback (via verify_spotting)
spotting → skipped (via skip_spotting)
feedback → feedback (revisit: read-only)
skipped → skipped (revisit: correction accessible)
```

### Helper Methods (StudentSession)

| Method | Arguments | Returns | Description |
|---|---|---|---|
| `question_step(question_id)` | Integer | String or nil | Returns current step for a question |
| `set_question_step!(question_id, step)` | Integer, String | void | Sets and persists the step |
| `store_spotting!(question_id, data)` | Integer, Hash | void | Stores spotting result |
| `spotting_data(question_id)` | Integer | Hash or nil | Returns stored spotting result |
| `spotting_completed?(question_id)` | Integer | Boolean | True if step is feedback or skipped |
| `tutored_active?` | none | Boolean | `tutored? && tutor_state.present?` |

## Existing Entities Used (read-only)

### Question → Answer

| Field | Usage |
|---|---|
| `questions.answer_type` | Determines correct radio choice (enum: text, calculation, argumentation, dr_reference, completion, choice) |
| `answers.data_hints` | JSONB array of `{source, location}`. Determines correct checkboxes and feedback text |

### Subject

| Field | Usage |
|---|---|
| `subjects.dt_file` | Existence determines if "DT" appears in checkbox options |
| `subjects.dr_vierge_file` | Existence determines if "DR" appears in checkbox options |
| `subjects.presentation_text` | Existence determines if "Mise en situation" appears in checkbox options |

## Source Normalization Mapping

| Raw `data_hints.source` pattern | Normalized category | Checkbox label |
|---|---|---|
| `/^DT/i` (DT, DT1, DT2...) | `dt` | "Document Technique (DT)" or "DT1", "DT2" |
| `/^DR/i` (DR, DR1, DR2...) | `dr` | "Document Réponse (DR)" |
| `enonce`, `question_context` | `enonce` | "Énoncé de la question" |
| `mise_en_situation`, `tableau_sujet` | `mise_en_situation` | "Mise en situation" |
| Other | ignored | Not shown |

## Task Type Mapping

| `answer_type` value | French label |
|---|---|
| `calculation` | Calculer une valeur |
| `text` | Rédiger une réponse |
| `argumentation` | Justifier ou argumenter |
| `dr_reference` | Compléter un document réponse |
| `completion` | Compléter un schéma ou tableau |
| `choice` | Choisir parmi des options |
