# Research: Tuteur guidé — Micro-tâches de repérage

## R1: Storage pattern for tutor workflow state

**Decision**: JSONB column `tutor_state` on existing `student_sessions` table.

**Rationale**: One `StudentSession` per student-subject pair already exists (uniqueness constraint). Adding a JSONB column avoids creating a new table. The tutor state is per-question within a subject — fits naturally as nested JSON. Same pattern as existing `progression` JSONB column.

**Alternatives considered**:
- New `tutor_spotting_results` table — rejected: unnecessary complexity for MVP. Data is always accessed alongside the session.
- Store in `conversations.messages` — rejected: spotting is structured data (not chat messages), and subject-level state has no conversation to attach to.

## R2: Spotting validation logic — server-side vs client-side

**Decision**: Server-side validation via POST to `TutorController#verify_spotting`, response as Turbo Stream.

**Rationale**: Constitution requires all logic in services/controllers (thin controllers, logic in services). Server-side ensures the correct answers can't be inspected in client JS. Turbo Stream response replaces the spotting card with feedback — no full page reload.

**Alternatives considered**:
- Client-side JS validation — rejected: answer data would need to be in the DOM (inspectable by students).
- Inline Stimulus validation with hidden data attributes — rejected: same inspection risk.

## R3: Source normalization from data_hints

**Decision**: Normalize `data_hints[].source` values into display categories using a mapping service.

**Rationale**: `data_hints` sources are free-text from AI extraction (e.g., "DT", "DT1", "DT2", "tableau_sujet", "enonce", "mise_en_situation", "question_context"). Need to map to checkbox labels the student understands.

**Mapping**:
- `/^DT/i` → "Document Technique (DT)" (or "DT1", "DT2" if multiple)
- `/^DR/i` → "Document Réponse (DR)"
- `"enonce"`, `"question_context"` → "Énoncé de la question"
- `"mise_en_situation"`, `"tableau_sujet"` → "Mise en situation"
- Other → ignored (not shown as checkbox)

**Alternatives considered**:
- Show raw source text — rejected: inconsistent labels confuse students.
- Regex-only in view — rejected: keep logic in a service for testability.

## R4: Distractor generation for task type radio

**Decision**: Static mapping from `answer_type` enum to 3-4 radio options (correct + 2-3 distractors).

**Rationale**: The `answer_type` enum has 6 values: text, calculation, argumentation, dr_reference, completion, choice. For each correct type, select 2-3 others as distractors. This is deterministic, no IA needed.

**Example**: If `answer_type == "calculation"`:
- ✓ Calculer une valeur
- ✗ Justifier un choix (argumentation)
- ✗ Compléter un document (dr_reference)
- ✗ Rédiger une réponse (text)

**Alternatives considered**:
- AI-generated distractors — rejected: unnecessary complexity and cost for a fixed enum.
- Show all 6 options always — rejected: too many choices. 3-4 is optimal for quick selection.

## R5: Turbo Frame strategy for spotting card

**Decision**: Single Turbo Frame `spotting_question_{id}` wrapping the spotting card. `verify_spotting` returns a Turbo Stream `replace` targeting this frame with the feedback partial.

**Rationale**: Clean replacement of form → feedback without full page reload. Compatible with Turbo's existing frame pattern used in the correction reveal flow.

**Alternatives considered**:
- Stimulus-only toggle (hide form, show feedback in JS) — rejected: state not persisted, inspection risk.
- Full page redirect — rejected: disrupts scroll position and feels heavy.
