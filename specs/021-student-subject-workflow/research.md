# Research: Workflow sujet complet élève

**Date**: 2026-04-08

## R1: Part completion tracking — where to store?

**Decision**: Store in existing `progression` JSONB under a `parts_completed` key (array of part IDs).

**Rationale**: No migration needed. The JSONB field is already used for question-level tracking with numeric string keys. A top-level `parts_completed` key is a distinct namespace that won't conflict. Array lookup is O(n) but n is ≤10 parts per subject — trivial.

**Alternatives considered**:
- New `parts_completed` column (array or JSONB): Requires migration. Overkill for 2-10 boolean flags.
- Derive from question progress (part is "completed" if all questions seen): Doesn't match the UX requirement — the student explicitly clicks "Fin de la partie" even if they skipped questions.
- Store in `tutor_state`: Semantically wrong — this isn't tutor-related.

## R2: Navigation context for review mode

**Decision**: Use `?from=review` query parameter on question links from the unanswered questions page.

**Rationale**: Stateless, simple, lost on sidebar navigation (which is the correct behavior). No session pollution.

**Alternatives considered**:
- Store `review_mode` flag in session: Sticky state that requires cleanup. Risk of stale state if student navigates away.
- Turbo Frame isolation: Over-engineered for a simple redirect change.

## R3: Specific presentation display trigger

**Decision**: Show specific presentation when the student starts the specific part AND hasn't seen it yet. Track via a `specific_presentation_seen` boolean in `progression`.

**Rationale**: Needs a flag because the student may leave and come back. Without it, the presentation would re-display every time.

**Alternatives considered**:
- Always show it before specific questions: Annoying on re-entry.
- Never track it (show once per page load): Would re-show on every visit to subject#show when specific part is next.

## R4: Subject completion state

**Decision**: Store `completed_at` timestamp in `progression` JSONB. A subject is "completed" when the student explicitly clicks "Terminer le sujet" OR when all questions are answered after all parts are completed.

**Rationale**: Allows distinguishing between "in progress" and "done". The timestamp is useful for future analytics. Stored in `progression` to avoid migration.

**Alternatives considered**:
- Boolean `completed` column: Requires migration.
- Derive from question progress only: Doesn't capture the "Terminer le sujet" explicit action.

## R5: Workflow routing complexity

**Decision**: Single `subjects#show` action with priority-based routing (7 conditions). No new controller.

**Rationale**: The show action already handles scope selection and first-visit presentation. Adding 4 more conditions is simpler than splitting into multiple actions/controllers. The routing is deterministic and testable.

**Alternatives considered**:
- Separate controller (`StudentWorkflowController`): Overkill. Would duplicate subject loading logic.
- State machine gem: Adds dependency for a simple linear flow.
