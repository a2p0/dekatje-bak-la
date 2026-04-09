# Research: 025 — Design System

## 1. Plus Jakarta Sans Loading

**Decision**: Self-host font files via `@font-face`
**Rationale**: Constitution V — "assets compiled locally, no external CDN"
**Implementation**: Download woff2 from Google Fonts, place in `app/assets/fonts/`, `@font-face` in application.css
**Alternatives rejected**: Google Fonts CDN URL (external dependency)

## 2. Design Tokens Strategy

**Decision**: Tailwind CSS 4 `@theme` directive + CSS custom properties
**Rationale**: Idiomatic Tailwind 4 approach. `@theme` values become utility classes automatically. CSS custom properties enable dark/light token switching.
**Alternatives rejected**: Separate CSS variables file (duplicates effort, no Tailwind integration)

## 3. Focus Trap

**Decision**: Custom Stimulus controller (`focus_trap_controller.js`)
**Rationale**: ~40 lines of JS. Handles Tab/Shift+Tab cycling and Escape to close. Reused by sidebar, chat drawer, modal.
**Alternatives rejected**: focus-trap npm package (adds dependency for minimal functionality)

## 4. Confetti Animation

**Decision**: canvas-confetti package (6KB gzipped)
**Rationale**: One-shot API call, well-maintained, no persistent dependency. Pure CSS confetti is hacky and limited.
**Implementation**: `import confetti from 'canvas-confetti'` in Stimulus controller, fire on `connect()`
**Alternatives rejected**: Pure CSS (limited), custom canvas code (unnecessary effort)

## 5. Badge Light/Dark Fix

**Decision**: Separate Tailwind classes for light and dark modes
**Rationale**: Current BadgeComponent uses identical classes for both modes (e.g., `text-indigo-300` in both), causing low contrast on light backgrounds.
**Implementation**: Light: `bg-{color}-100 text-{color}-700`, Dark: `bg-{color}-500/15 text-{color}-400`
**Alternatives rejected**: CSS custom properties per badge color (over-engineering for 6 color variants)
