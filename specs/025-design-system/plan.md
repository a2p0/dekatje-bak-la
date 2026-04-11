# Implementation Plan: 025 — Design System & Pages Élève

**Branch**: `025-design-system` | **Date**: 2026-04-08 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/025-design-system/spec.md`

## Summary

Implement a cohesive "Moderne & Vibrant" design system using Tailwind CSS 4 with Plus Jakarta Sans font, then apply it to all student pages and the public home page. Includes fixing 8 WCAG AA accessibility issues, creating a student layout, correcting existing ViewComponents, and adding new ones (Breadcrumb, BottomBar, Confetti).

## Technical Context

**Language/Version**: Ruby 3.3+ / Rails 8.1  
**Primary Dependencies**: Tailwind CSS 4 (already installed), Plus Jakarta Sans (Google Fonts), Stimulus, ViewComponent  
**Storage**: N/A (no schema changes)  
**Testing**: RSpec + Capybara feature specs  
**Target Platform**: Web — mobile-first, Chrome + Firefox  
**Project Type**: Web application (fullstack Rails + Hotwire)  
**Performance Goals**: N/A (MVP — prefer simplicity)  
**Constraints**: Lightweight assets, no external CDN (constitution V). Mobile-first for Martinique lycéens.  
**Scale/Scope**: ~15 view files to restyle, 7 ViewComponents to update/create, 2 layouts, 8 a11y fixes

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|---|---|---|
| I. Fullstack Rails — Hotwire Only | ✅ PASS | Pure Tailwind + Stimulus, no SPA |
| II. RGPD & Protection des mineurs | ✅ PASS | No data changes, no new student data collected |
| III. Security | ✅ PASS | No API key changes, no new secrets |
| IV. Testing | ✅ PASS | Feature specs for every visual change |
| V. Performance & Simplicity | ✅ PASS | Google Fonts loaded locally (no CDN). Simple, readable code. |
| VI. Development Workflow | ✅ PASS | Plan validated before coding, feature branch, PR systematic |

No violations. No complexity tracking needed.

## Project Structure

### Documentation (this feature)

```text
specs/025-design-system/
├── spec.md              # Feature specification (complete)
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output (minimal — no schema changes)
├── quickstart.md        # Phase 1 output
└── tasks.md             # Phase 2 output (speckit-tasks)
```

### Source Code (repository root)

```text
app/
├── assets/
│   └── tailwind/
│       └── application.css          # Design tokens (CSS custom properties)
├── components/                      # ViewComponents
│   ├── badge_component.rb           # FIX: light/dark distinct styles
│   ├── bottom_bar_component.rb      # NEW: mobile fixed bar (prev/next + tutorat)
│   ├── breadcrumb_component.rb      # NEW: Sujet › Partie › Question
│   ├── button_component.rb          # ENRICH: gradient variant
│   ├── card_component.rb            # ENRICH: glow variant
│   ├── confetti_component.rb        # NEW: Bravo page animation
│   ├── modal_component.rb           # FIX: focus trap, Escape, a11y
│   ├── nav_bar_component.rb         # ENRICH: breadcrumb support
│   └── progress_bar_component.rb    # ENRICH: gradient variant
├── javascript/
│   └── controllers/
│       ├── confetti_controller.js   # NEW: animation trigger
│       └── focus_trap_controller.js # NEW: reusable focus trap
├── views/
│   ├── layouts/
│   │   ├── application.html.erb     # FIX: lang="fr", skip link, font
│   │   ├── student.html.erb         # NEW: student layout with NavBar
│   │   └── teacher.html.erb         # FIX: lang="fr", skip link, font
│   ├── home/
│   │   └── index.html.erb           # REDESIGN: mix A+C
│   └── student/
│       ├── sessions/new.html.erb    # RESTYLE
│       ├── subjects/index.html.erb  # RESTYLE + header perso
│       ├── subjects/show.html.erb   # RESTYLE + bravo festif
│       ├── questions/show.html.erb  # RESTYLE + bottom bar + breadcrumb
│       ├── questions/_sidebar.html.erb  # RESTYLE + présentations
│       ├── questions/_correction.html.erb  # RESTYLE
│       ├── questions/_chat_drawer.html.erb # RESTYLE + a11y
│       └── settings/show.html.erb   # RESTYLE
└── spec/
    └── features/
        └── (existing specs — update selectors/text as needed)
```

**Structure Decision**: Standard Rails structure, no new directories. Changes are primarily in views, components, and assets.

## Phase 0: Research

### Research Tasks

No NEEDS CLARIFICATION items — all technology choices are known and already in use. Key decisions to document:

1. **Plus Jakarta Sans loading strategy** — self-hosted vs Google Fonts URL, given constitution constraint "no external CDN"
2. **CSS custom properties vs Tailwind theme extension** — how to implement design tokens in Tailwind CSS 4
3. **Focus trap implementation** — Stimulus controller vs existing library
4. **Confetti animation** — lightweight library vs pure CSS

### Research Findings

#### 1. Plus Jakarta Sans loading

**Decision**: Self-host the font files via `@font-face` in `application.css`
**Rationale**: Constitution V mandates "assets compiled locally, no external CDN". Google Fonts URL would be an external dependency.
**Alternative rejected**: Google Fonts CDN link — violates constitution, adds external dependency.
**Implementation**: Download woff2 files, place in `app/assets/fonts/`, declare `@font-face` in Tailwind CSS.

#### 2. Design tokens strategy

**Decision**: Tailwind CSS 4 `@theme` directive with CSS custom properties
**Rationale**: Tailwind 4 natively supports `@theme` for extending the default theme with custom values. CSS custom properties enable dark mode token switching. This is the idiomatic Tailwind 4 approach.
**Alternative rejected**: Separate CSS custom properties file outside Tailwind — duplicates effort, doesn't integrate with utility classes.

#### 3. Focus trap

**Decision**: Custom Stimulus controller (`focus_trap_controller.js`)
**Rationale**: Simple, no dependency. Only need to trap Tab/Shift+Tab within a container and handle Escape. Used by sidebar, chat drawer, and modal.
**Alternative rejected**: focus-trap npm package — adds a dependency for ~40 lines of JS.

#### 4. Confetti animation

**Decision**: canvas-confetti npm package (lightweight, 6KB gzipped)
**Rationale**: Pure CSS confetti is limited and hacky. canvas-confetti is a one-shot call, no persistent dependency, well-maintained.
**Alternative rejected**: Pure CSS — limited control, ugly at scale. Custom canvas code — more work than necessary.

## Phase 1: Design

### Data Model

No schema changes. No new models, migrations, or database modifications.

### Interface Contracts

No new external interfaces. All changes are internal (views, components, CSS).

### Design Tokens (application.css)

```css
@import "tailwindcss";
@import url("../fonts/plus-jakarta-sans.css");

@custom-variant dark (&:where(.dark, .dark *));

@theme {
  /* Brand */
  --color-primary-gradient-from: #6366f1;
  --color-primary-gradient-to: #8b5cf6;

  /* Glow */
  --shadow-glow-indigo: 0 0 16px rgba(99, 102, 241, 0.3);
  --shadow-glow-emerald: 0 0 12px rgba(16, 185, 129, 0.2);
  --shadow-glow-indigo-sm: 0 0 8px rgba(99, 102, 241, 0.1);

  /* Border radius */
  --radius-card: 1rem;      /* 16px — rounded-xl */
  --radius-button: 0.75rem; /* 12px — rounded-lg */
  --radius-input: 0.75rem;  /* 12px */
  --radius-pill: 9999px;    /* rounded-full */

  /* Font */
  --font-family-sans: 'Plus Jakarta Sans', system-ui, sans-serif;

  /* Z-index scale */
  --z-sidebar: 30;
  --z-bottom-bar: 35;
  --z-backdrop: 40;
  --z-chat-drawer: 45;
  --z-modal: 50;

  /* Transitions */
  --transition-fast: 150ms ease;
  --transition-normal: 300ms ease;
}
```

### Component Architecture

#### New Components

| Component | Props | Purpose |
|---|---|---|
| `BreadcrumbComponent` | `items: [{label, href}]` | Compact breadcrumb `Sujet › Partie › Q`. Renders `<nav aria-label="Fil d'Ariane">` with `aria-current="page"` on last item |
| `BottomBarComponent` | `prev_href, next_href, next_label, tutorat_action` | Mobile fixed bar |
| `ConfettiComponent` | (none) | Triggers confetti on connect via Stimulus |

#### Modified Components

| Component | Changes |
|---|---|
| `BadgeComponent` | Separate light/dark classes. Light: `bg-{color}-100 text-{color}-700`. Dark: `bg-{color}-500/15 text-{color}-400` |
| `ButtonComponent` | Add `:gradient` variant (indigo→violet + glow shadow). States: hover darkens gradient 10%, focus-visible uses ring pattern, disabled desaturates gradient |
| `CardComponent` | Add `:glow` variant (border-indigo + box-shadow glow in dark) |
| `ModalComponent` | Add focus_trap_controller, Escape key, aria-labelledby, close button |
| `NavBarComponent` | Accept breadcrumb slot, ensure theme toggle always visible |
| `ProgressBarComponent` | Add `:gradient` color option (indigo→violet) |

#### New Stimulus Controllers

| Controller | Purpose |
|---|---|
| `focus_trap_controller` | Reusable: trap Tab/Shift+Tab in container, Escape to close. Used by sidebar, chat, modal. |
| `confetti_controller` | Fire canvas-confetti burst on `connect()` |

### Layout Architecture

#### New: `student.html.erb`

Replaces per-view NavBar rendering. Structure:
```
<html lang="fr" class="dark">
  <body>
    <a href="#main-content" class="sr-only focus:not-sr-only">Aller au contenu</a>
    <NavBarComponent with breadcrumb + theme toggle + settings + logout />
    <main id="main-content">
      <%= yield %>
    </main>
  </body>
</html>
```

All student controllers set `layout "student"` **except** `SessionsController` (login page uses `application` layout — student is not authenticated, no NavBar).

#### Modified: `application.html.erb` and `teacher.html.erb`

- Add `lang="fr"` on `<html>`
- Add skip navigation link
- Add Plus Jakarta Sans font loading
- Add `aria-live="polite"` region for flash messages

### Page-by-Page Implementation Plan

#### 1. Home page (`home/index.html.erb`)
- Hero centré + carte unifiée (élève + enseignant)
- Below the fold: features grid + workflow steps
- Dark gradient background with radial glow

#### 2. Student login (`student/sessions/new.html.erb`)
- Même ambiance que home: dark gradient, carte centrée
- Formulaire avec inputs rounded-lg, bouton gradient

#### 3. Subjects index (`student/subjects/index.html.erb`)
- Header "Salut [prénom]"
- CardComponent glow variant sur chaque sujet
- ProgressBar gradient sur chaque carte

#### 4. Subject show (`student/subjects/show.html.erb`)
- Breadcrumb
- Cartes parties avec glow hover
- Bouton "Commencer" en gradient
- Page Bravo: ConfettiComponent + titre gradient

#### 5. Question show (`student/questions/show.html.erb`)
- Breadcrumb compact
- BottomBarComponent (mobile only, hidden lg:)
- Bouton Tutorat agrandi dans progress bar (desktop)
- Question card avec glow
- Sidebar: présentations commune/spécifique ajoutées

#### 6. Chat drawer (`student/questions/_chat_drawer.html.erb`)
- Mobile: plein écran + header contextuel question
- A11y: aria-label input, focus_trap_controller, aria-live on streaming

#### 7. Settings (`student/settings/show.html.erb`)
- Cartes glow, arrondis xl
- Radio buttons avec gradient sur sélection
- Breadcrumb

### Accessibility Implementation

| Fix | Where | How |
|---|---|---|
| `lang="fr"` | All layouts | Add to `<html>` tag |
| Skip link | All layouts | `<a href="#main-content" class="sr-only focus:not-sr-only">` |
| Focus trap | sidebar, chat, modal | `focus_trap_controller` Stimulus |
| Chat input label | `_chat_drawer.html.erb` | `aria-label="Écrivez votre question"` |
| aria-live | Flash (all layouts), chat streaming (`aria-live="polite"`), errors (`role="alert"`) | `aria-live="polite"` on flash + streaming, `role="alert"` on error divs |
| aria-expanded | All toggles (sidebar, chat, data-hints) | Add to toggle buttons |
| Contrast | All views | Replace `text-slate-400` → `text-slate-600` on light backgrounds, `text-slate-400` stays on dark (slate-600 = #475569, ~7:1 on white) |
| prefers-reduced-motion | All layouts + confetti | `@media (prefers-reduced-motion: reduce)` disables transitions/glow; confetti JS guard |
| aria-describedby | Devise forms, settings form | Link error messages to fields |

## Phase 2: Implementation Order

> Not detailed here — generated by `speckit-tasks`.

Implementation should follow this dependency order:
1. **Foundation** — font, tokens, layouts, a11y base (skip link, lang)
2. **Components** — fix/create all components
3. **Pages** — restyle page by page (home → login → index → subject → question → settings)
4. **Polish** — confetti, glow fine-tuning, responsive QA

Each page restyle should be followed by running existing feature specs to catch regressions.
