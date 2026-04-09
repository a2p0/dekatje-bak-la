# Quickstart: 025 — Design System

## Prerequisites

- Ruby 3.3+, Rails 8.1 (already set up)
- Tailwind CSS 4 (already installed)
- Node.js for asset compilation

## Getting Started

```bash
# Start dev environment
bin/dev

# Run tests (CI is authoritative, local is slow)
bundle exec rspec

# Compile assets
bin/rails tailwindcss:build
```

## Key Files to Edit

1. **Design tokens**: `app/assets/tailwind/application.css`
2. **Font files**: `app/assets/fonts/` (new directory)
3. **ViewComponents**: `app/components/`
4. **Student layout**: `app/views/layouts/student.html.erb` (new)
5. **Stimulus controllers**: `app/javascript/controllers/`
6. **Student views**: `app/views/student/`
7. **Home page**: `app/views/home/index.html.erb`

## Testing Strategy

- Run existing feature specs after each page restyle to catch regressions
- Update CSS selectors in specs if class names change
- Add feature specs for new components (breadcrumb, bottom bar)
- Visual inspection in both light and dark mode
- Test mobile responsiveness at 375px width

## Font Installation

```bash
# Download Plus Jakarta Sans woff2 files
mkdir -p app/assets/fonts
# Place woff2 files (400, 500, 600, 700 weights) in app/assets/fonts/
```
