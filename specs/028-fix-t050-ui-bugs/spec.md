# Feature Specification: Fix T050 UI Bugs — Student Question Page

**Feature Branch**: `028-fix-t050-ui-bugs`
**Created**: 2026-04-11
**Status**: Draft
**Input**: Fix 6 UI bugs from manual testing T050 on the student question page.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Question navigation starts at the common part (Priority: P1)

When a student starts a complete subject (with common + specific parts), the first question displayed must be Q1.1 from the common part, not QA.1 from a specific part. Common parts always come before specific parts in the navigation order.

**Why this priority**: Students following the wrong question order may answer out of context, impacting their exam preparation.

**Independent Test**: Start a subject with both common and specific parts → first question shown is from the common section.

**Acceptance Scenarios**:

1. **Given** a published subject with common part (Q1.1, Q1.2) and specific part (QA.1), **When** the student clicks "Commencer", **Then** the first question displayed is Q1.1 (common).
2. **Given** a subject with only specific parts, **When** the student clicks "Commencer", **Then** the first question of the first specific part is displayed.

---

### User Story 2 - Context text displayed in a separate card above the question (Priority: P1)

When a question has context text (`context_text`), it must appear in its own card above the question card, not inline inside the question card. This makes the visual hierarchy clearer: context first, then the question.

**Why this priority**: Students need to read the context before reading the question — the current layout buries context inside the question card.

**Independent Test**: Visit a question with context text → see two cards: one for context, one for the question.

**Acceptance Scenarios**:

1. **Given** a question with context text, **When** the student views the question page, **Then** the context appears in a separate card above the question card.
2. **Given** a question without context text, **When** the student views the question page, **Then** only the question card is displayed (no empty context card).

---

### User Story 3 - Human-readable source labels in data hints (Priority: P2)

In the "Où trouver les données ?" section, source tags must display human-readable labels instead of raw technical keys. For example: "Contexte" instead of "question_context", "Présentation" instead of "mise_en_situation".

**Why this priority**: Raw technical labels confuse students and break the pedagogical experience.

**Independent Test**: View a question correction with data hints containing "question_context" → see "Contexte" displayed.

**Acceptance Scenarios**:

1. **Given** a question with `data_hints` containing `source: "question_context"`, **When** the correction is displayed, **Then** the badge shows "Contexte".
2. **Given** a question with `data_hints` containing `source: "mise_en_situation"`, **When** the correction is displayed, **Then** the badge shows "Présentation".
3. **Given** a question with `data_hints` containing `source: "DT1"`, **When** the correction is displayed, **Then** the badge shows "DT1" (unchanged, already readable).

---

### User Story 4 - Consistent badge colors for DT/DR across the page (Priority: P2)

Badge colors for document references must be consistent everywhere on the question page. Currently, the question card shows DT in blue and DR in orange, but the "Où trouver les données ?" section shows both in orange.

**Why this priority**: Inconsistent colors confuse students about which document type is referenced.

**Independent Test**: View a question with DT and DR references → badges use the same color scheme in all sections.

**Acceptance Scenarios**:

1. **Given** a question referencing DT documents, **When** viewing data hints in correction, **Then** DT badges are blue (matching the question card).
2. **Given** a question referencing DR documents, **When** viewing data hints in correction, **Then** DR badges are orange/amber (matching the question card).
3. **Given** a question referencing "question_context" or "mise_en_situation", **When** viewing data hints, **Then** these badges use a neutral color (slate or indigo).

---

### User Story 5 - Data hints section at the top of correction (Priority: P2)

The "Où trouver les données ?" section must appear at the top of the correction partial, before the correction text. Currently it appears after the correction and explanation.

**Why this priority**: Students should see where the data was located before reading the correction — it helps them understand the methodology.

**Independent Test**: Reveal a correction → "Où trouver les données ?" section appears first, before the correction text.

**Acceptance Scenarios**:

1. **Given** a question with data hints and a correction, **When** the correction is revealed, **Then** "Où trouver les données ?" appears above "✓ Correction".
2. **Given** a question without data hints, **When** the correction is revealed, **Then** the correction displays normally (no empty section).

---

### User Story 6 - Specific presentation shown when starting the specific part (Priority: P1)

When transitioning from the common part to the specific part, the student must see the specific presentation (mise en situation spécifique) before starting the first question of the specific section.

**Why this priority**: The specific presentation provides essential context for the specific part — skipping it means students lack the background needed for those questions.

**Independent Test**: Complete the common part → transition to specific part → see the specific presentation before the first specific question.

**Acceptance Scenarios**:

1. **Given** a student completing the last question of the common section, **When** they proceed to the specific section, **Then** the specific presentation is displayed before the first specific question.
2. **Given** a student navigating directly to a specific part via the sidebar, **When** they click on a specific part, **Then** the specific presentation is shown first (if not already seen).
3. **Given** a student who has already seen the specific presentation, **When** they return to a specific question, **Then** the presentation is not shown again.

---

### Edge Cases

- What happens when a subject has no common parts? → Specific parts start directly, no reordering needed.
- What happens when a question has no data hints? → "Où trouver les données ?" section is not displayed at all.
- What happens when `context_text` is empty or nil? → No context card is rendered.
- What happens when `specific_presentation` is nil? → No presentation step, go directly to the first specific question.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST display common parts before specific parts when navigating a complete subject.
- **FR-002**: System MUST render `context_text` in a separate visual card above the question card.
- **FR-003**: System MUST translate raw source keys to human-readable labels in data hints: `question_context` → "Contexte", `mise_en_situation` → "Présentation", `enonce` → "Énoncé", `tableau_sujet` → "Tableau du sujet". DT/DR keys are kept as-is.
- **FR-004**: System MUST use consistent badge colors across the page: DT sources in blue, DR sources in amber, other sources in a neutral color.
- **FR-005**: System MUST display the "Où trouver les données ?" section at the top of the correction partial, before the correction text.
- **FR-006**: System MUST show the specific presentation when a student first enters the specific section, regardless of how they navigate there (part transition, sidebar click, or direct URL).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Students always start a complete subject at Q1.1 (common), never at a specific question.
- **SC-002**: Context text is visually separated from the question text (two distinct cards).
- **SC-003**: No raw technical keys (question_context, mise_en_situation, etc.) are visible to students.
- **SC-004**: Badge colors for DT/DR are identical in all sections of the question page.
- **SC-005**: "Où trouver les données ?" is the first section visible after revealing a correction.
- **SC-006**: Students always see the specific presentation before their first specific question.

## Assumptions

- The fix preserves existing Capybara feature specs — any broken spec is updated to match the new behavior.
- The source label translation is done via a helper method, not hardcoded in each view.
- The "Où trouver les données ?" section is moved within the existing `_correction.html.erb` partial (reordered to the top, not duplicated).
- The pre-correction "Où trouver les données ?" collapsible (in `show.html.erb`) is removed since the section now appears with the correction.
