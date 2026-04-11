# Research: Fix T050 UI Bugs

**Date**: 2026-04-11

## No NEEDS CLARIFICATION

All 6 bugs are well-defined view/controller issues with clear fixes. No technology choices or architectural decisions needed.

## Key Findings

### Bug 1 — Starting question order
- `all_parts_for_subject` already puts common before specific (line 189).
- Root cause: `target_part` (line 226) finds first incomplete part regardless of section_type. If common parts are all completed but specific parts exist, it returns the first specific part — which is correct. The real issue may be in how `position` values are assigned during extraction.
- Decision: Debug with real data to confirm root cause before changing code.

### Bug 5 — Data hints position
- The `_correction.html.erb` partial currently orders: correction → explanation → data hints → key concepts.
- Decision: Move data hints to the top of the partial (before correction). Simple reorder.
- The pre-correction "Où trouver les données ?" collapsible in `show.html.erb` becomes redundant and should be removed.

### Bug 6 — Specific presentation
- `should_show_specific_presentation?` is only called at step 6 of `show` action.
- Step 7 (`target_part` → redirect to question) bypasses this check.
- Decision: Add the presentation check before the step 7 redirect when the target part is specific.
