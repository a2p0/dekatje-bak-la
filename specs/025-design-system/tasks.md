# Tasks: 025 — Design System & Pages Élève

**Input**: Design documents from `/specs/025-design-system/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

**Tests**: Feature specs required (constitution IV — Capybara for every user-facing behavior).

**Organization**: Tasks grouped by user story for independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1–US6)

## User Stories (from spec)

- **US1**: Design system foundation (tokens, font, layouts, a11y base)
- **US2**: ViewComponents fix & creation
- **US3**: Home page redesign
- **US4**: Student login redesign
- **US5**: Student subject pages redesign (index, show, bravo)
- **US6**: Student question page redesign (question, sidebar, chat, settings)

---

## Phase 1: Setup

**Purpose**: Install dependencies and prepare assets

- [x] T001 Download Plus Jakarta Sans woff2 files (400, 500, 600, 700) and place in `app/assets/fonts/`
- [x] T002 Create `@font-face` declarations with `font-display: swap` in `app/assets/fonts/plus-jakarta-sans.css`
- [x] T003 Install canvas-confetti package via `importmap pin canvas-confetti` — verify jspm/jsdelivr availability first; fallback to pure CSS if unavailable

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Design tokens, layouts, and a11y infrastructure that ALL pages depend on

**⚠️ CRITICAL**: No page restyling can begin until this phase is complete

- [x] T004 Define design tokens in `app/assets/tailwind/application.css` — `@theme` with gradient colors, glow shadows, radius values, font-family, z-index scale (sidebar/bottom-bar/backdrop/chat/modal), transition tokens (fast/normal)
- [x] T005 Import Plus Jakarta Sans font in `app/assets/tailwind/application.css`
- [x] T006 [P] Add `lang="fr"` to `<html>`, `aria-live="polite"` on flash container in `app/views/layouts/application.html.erb`
- [x] T007 [P] Add `lang="fr"` to `<html>`, `aria-live="polite"` on flash container in `app/views/layouts/teacher.html.erb`
- [x] T008 Create student layout `app/views/layouts/student.html.erb` with NavBarComponent, skip link, `lang="fr"`, `aria-live` flash region
- [x] T009 Add skip navigation link (`<a href="#main-content" class="sr-only focus:not-sr-only">`) in `app/views/layouts/application.html.erb`
- [x] T010 [P] Add skip navigation link in `app/views/layouts/teacher.html.erb`
- [x] T011 Create `focus_trap_controller.js` in `app/javascript/controllers/` — trap Tab/Shift+Tab, Escape dispatches `close` event. Define targets/values contract for sidebar, chat, modal integration
- [x] T011b [P] Add `prefers-reduced-motion` CSS reset in `app/assets/tailwind/application.css` — disable transitions/glow/transforms for users who request reduced motion
- [x] T012 Update all student controllers to use `layout "student"` and remove per-view NavBar rendering — **except** `SessionsController` (login stays on `application` layout)
- [x] T013a Update existing feature specs (student subjects/settings) to match new student layout (no changes needed — CI green)
- [x] T013b [P] Update existing feature specs (student questions/chat/sidebar) to match new student layout (no changes needed — CI green)

**Checkpoint**: Foundation ready — font loads, tokens defined, student layout works, a11y base in place, specs green

---

## Phase 3: User Story 2 — ViewComponents Fix & Creation (Priority: P1)

**Goal**: All shared components are correct before page restyling begins

**Independent Test**: Components render correctly in isolation (light + dark mode)

### Tests for US2

- [x] T014 [P] [US2] Add feature spec for BreadcrumbComponent rendering in `spec/components/breadcrumb_component_spec.rb`
- [x] T015 [P] [US2] Add feature spec for BottomBarComponent rendering in `spec/components/bottom_bar_component_spec.rb`

### Implementation for US2

- [x] T016 [P] [US2] Fix BadgeComponent light/dark styles in `app/components/badge_component.rb` — light: `bg-{color}-100 text-{color}-700`, dark: `bg-{color}-500/15 text-{color}-400`
- [x] T017 [P] [US2] Add `:gradient` variant to ButtonComponent in `app/components/button_component.rb` — indigo→violet gradient + glow shadow; hover darkens 10%, focus-visible ring, disabled desaturates
- [x] T018 [P] [US2] Add `:glow` variant to CardComponent in `app/components/card_component.rb` — border-indigo + box-shadow glow in dark
- [x] T019 [P] [US2] Add `:gradient` color option to ProgressBarComponent in `app/components/progress_bar_component.rb`
- [x] T020 [US2] Fix ModalComponent in `app/components/modal_component.rb` — add focus_trap_controller, Escape key, close button, `aria-labelledby`
- [x] T021 [US2] Add breadcrumb slot to NavBarComponent in `app/components/nav_bar_component.rb`
- [x] T022 [US2] Create BreadcrumbComponent in `app/components/breadcrumb_component.rb` — `items: [{label, href}]`, `<nav aria-label="Fil d'Ariane">` wrapper, `aria-current="page"` on last item
- [x] T023 [US2] Create BottomBarComponent in `app/components/bottom_bar_component.rb` — prev/next links + tutorat button, mobile only
- [x] T024 [US2] Create ConfettiComponent in `app/components/confetti_component.rb` + `app/javascript/controllers/confetti_controller.js` — check `prefers-reduced-motion` before firing

**Checkpoint**: All components ready. Badge readable in light mode, gradient buttons work, glow cards render, breadcrumb and bottom bar exist.

---

## Phase 4: User Story 3 — Home Page Redesign (Priority: P2)

**Goal**: Public home page with mix A+C layout (hero + carte unifiée + below the fold)

**Independent Test**: Visit `/` → see hero, access code field, enseignant link, features section, workflow section

### Tests for US3

- [x] T025 [US3] Add/update feature spec for home page in `spec/features/global_navigation_spec.rb` — hero, access code, enseignant link

### Implementation for US3

- [x] T026 [US3] Redesign `app/views/pages/home.html.erb` — above the fold: hero centré + carte unifiée (élève + enseignant) + theme toggle + gradient glow
- [x] T027 [US3] Add below-the-fold section to `app/views/pages/home.html.erb` — features grid (3 items) + workflow steps (3 étapes)

**Checkpoint**: Home page functional with new design in light + dark mode.

---

## Phase 5: User Story 4 — Student Login Redesign (Priority: P3)

**Goal**: Login page with same dark gradient ambiance as home page

**Independent Test**: Visit `/{access_code}` → see login form with gradient background, submit credentials

### Tests for US4

- [x] T028 [US4] Update feature spec for student login (no changes needed — labels and form structure preserved)

### Implementation for US4

- [x] T029 [US4] Restyle `app/views/student/sessions/new.html.erb` — dark gradient background, carte centrée, inputs rounded-xl, bouton gradient

**Checkpoint**: Login page matches home page ambiance.

---

## Phase 6: User Story 5 — Student Subject Pages (Priority: P4)

**Goal**: Subjects index with personal header + glow cards, subject show with festive bravo

**Independent Test**: Login → see "Salut [prénom]" + subject cards with glow → click subject → see parts → complete all → see confetti bravo

### Tests for US5

- [x] T030 [US5] Update feature spec for subjects index in `spec/features/student_login_and_subjects_spec.rb` — "Salut" header replaces "Mes sujets"
- [x] T031 [P] [US5] Update feature spec for bravo page in `spec/features/student/subject_workflow_spec.rb` — "Terminé" accent added

### Implementation for US5

- [x] T032 [US5] Restyle `app/views/student/subjects/index.html.erb` — "Salut [prénom]" header, CardComponent glow, ProgressBar gradient, badge fix
- [x] T033 [US5] Restyle `app/views/student/subjects/show.html.erb` — arrondis xl, glow cards, gradient "Commencer" button, breadcrumb
- [x] T034 [P] [US5] Restyle `app/views/student/subjects/_part_row.html.erb` — vibrant styling, BadgeComponent for completion
- [x] T035 [P] [US5] Restyle `app/views/student/subjects/_completion.html.erb` — festive bravo with ConfettiComponent, titre gradient
- [x] T036 [P] [US5] Restyle `app/views/student/subjects/_scope_selection.html.erb` — contrast fixes
- [x] T037 [P] [US5] Restyle `app/views/student/subjects/_specific_presentation.html.erb` — vibrant styling
- [x] T038 [P] [US5] Restyle `app/views/student/subjects/_unanswered_questions.html.erb` — vibrant styling

**Checkpoint**: Full subject flow works with new design. Bravo page has confetti.

---

## Phase 7: User Story 6 — Student Question Page (Priority: P5)

**Goal**: Question page with breadcrumb, bottom bar mobile, tutorat agrandi desktop, sidebar with présentations, chat a11y

**Independent Test**: Navigate to question → see breadcrumb + question card glow → mobile: bottom bar visible → chat: a11y labels + focus trap → sidebar: présentations accessible

### Tests for US6

- [ ] T039 [US6] Update feature spec for question page in `spec/features/student_question_spec.rb` — breadcrumb, bottom bar, tutorat button
- [ ] T040 [P] [US6] Update feature spec for chat in `spec/features/student_chat_spec.rb` — a11y attributes

### Implementation for US6

- [ ] T041 [US6] Restyle `app/views/student/questions/show.html.erb` — BreadcrumbComponent, BottomBarComponent (mobile), tutorat button agrandi (desktop), question card glow, arrondis xl, focus_trap_controller on sidebar
- [ ] T042 [US6] Restyle `app/views/student/questions/_sidebar.html.erb` — add présentations commune (before Partie 1) + spécifique (before first specific part), vibrant dark styling, add `aria-label="Navigation du sujet"` on aside
- [ ] T043 [US6] Restyle `app/views/student/questions/_correction.html.erb` — vibrant styling, glow cards
- [ ] T044 [US6] Restyle `app/views/student/questions/_chat_drawer.html.erb` — mobile plein écran + header contextuel question, `aria-label` on input, focus_trap_controller + Escape key, `aria-live="polite"` on streaming div, `role="alert"` on error div
- [ ] T045 [US6] Add `aria-expanded` to all toggle buttons (sidebar open, chat open, data-hints toggle) in question views
- [ ] T046 [US6] Restyle `app/views/student/settings/show.html.erb` — glow cards, arrondis xl, radio gradient selection, breadcrumb

**Checkpoint**: Full question workflow works. Mobile bottom bar functional. Chat accessible. Présentations in sidebar.

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Final validation across all pages

- [ ] T047 [P] Visual QA: verify all pages in light mode — contrast, readability, badge visibility
- [ ] T048 [P] Visual QA: verify all pages in dark mode — glow rendering, border tints, gradient visibility
- [ ] T049 [P] Responsive QA: verify all student pages at 375px width (mobile) and 1024px (desktop)
- [ ] T050 Run full feature spec suite — ensure no regressions
- [ ] T051 [P] Add `aria-describedby` for form errors in Devise views (`app/views/devise/`) and settings form
- [ ] T052 Clean up removed per-view NavBar code and unused CSS
- [ ] T053 [P] Replace all `text-[13px]` occurrences with `text-sm` in student views

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **Foundational (Phase 2)**: Depends on Setup — BLOCKS all user stories
- **US2 Components (Phase 3)**: Depends on Foundational — BLOCKS page restyling
- **US3 Home (Phase 4)**: Depends on US2
- **US4 Login (Phase 5)**: Depends on US2
- **US5 Subjects (Phase 6)**: Depends on US2
- **US6 Question (Phase 7)**: Depends on US2
- **Polish (Phase 8)**: Depends on all US complete

### User Story Dependencies

- **US3 (Home)**: Independent — no dependency on other US
- **US4 (Login)**: Independent — no dependency on other US
- **US5 (Subjects)**: Independent — no dependency on other US
- **US6 (Question)**: Independent — no dependency on other US
- US3, US4, US5, US6 can all proceed **in parallel** after US2 is complete

### Within Each User Story

- Tests written first (fail before implementation)
- Implementation follows plan.md page-by-page order
- Run existing feature specs after each page to catch regressions
- Commit after each task

### Parallel Opportunities

- T006, T007 in parallel (different layout files)
- T009, T010 in parallel (different layout files)
- T014, T015 in parallel (different spec files)
- T016, T017, T018, T019 in parallel (different component files)
- T034, T035, T036, T037, T038 in parallel (different partial files)
- After US2: US3, US4, US5, US6 can all start in parallel

---

## Parallel Example: US2 Components

```bash
# Launch all independent component fixes in parallel:
Task: "Fix BadgeComponent light/dark in app/components/badge_component.rb"
Task: "Add gradient variant to ButtonComponent in app/components/button_component.rb"
Task: "Add glow variant to CardComponent in app/components/card_component.rb"
Task: "Add gradient option to ProgressBarComponent in app/components/progress_bar_component.rb"
```

## Parallel Example: US5 Partials

```bash
# Launch all independent partial restyles in parallel:
Task: "Restyle _part_row.html.erb"
Task: "Restyle _completion.html.erb"
Task: "Restyle _scope_selection.html.erb"
Task: "Restyle _specific_presentation.html.erb"
Task: "Restyle _unanswered_questions.html.erb"
```

---

## Implementation Strategy

### MVP First (US2 + US6 = Question Page)

1. Complete Phase 1: Setup (font, confetti)
2. Complete Phase 2: Foundational (tokens, layouts, a11y)
3. Complete Phase 3: US2 Components
4. Complete Phase 7: US6 Question Page (most-used student page)
5. **STOP and VALIDATE**: Test question workflow independently
6. Then add remaining pages incrementally

### Incremental Delivery

1. Setup + Foundational → Foundation ready
2. US2 Components → All shared components fixed
3. US6 Question page → Core student experience redesigned
4. US5 Subject pages → Full student flow redesigned
5. US3 Home + US4 Login → Public pages redesigned
6. Polish → Final QA and cleanup

---

## Summary

| Metric | Count |
|---|---|
| **Total tasks** | 55 |
| **US2 (Components)** | 11 tasks |
| **US3 (Home)** | 3 tasks |
| **US4 (Login)** | 2 tasks |
| **US5 (Subjects)** | 9 tasks |
| **US6 (Question)** | 8 tasks |
| **Setup** | 3 tasks |
| **Foundational** | 12 tasks (T011b, T013a/T013b split) |
| **Polish** | 7 tasks (T053 added) |
| **Parallel opportunities** | 6 groups identified |

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Feature specs are mandatory (constitution IV)
- Commit after each task or logical group (constitution VI — one concern per commit)
- Run CI after each phase checkpoint (constitution VI)
- Self-host font (constitution V — no external CDN)
