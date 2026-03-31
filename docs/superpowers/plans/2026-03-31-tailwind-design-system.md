# Tailwind CSS + ViewComponent Design System — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate the entire app from inline styles to Tailwind CSS 4 + ViewComponent with an Indigo/Emerald palette, dark mode by default with light mode toggle.

**Architecture:** Install Tailwind CSS 4 (CSS-first config) and ViewComponent, create a shared component library (Button, Badge, Card, ProgressBar, NavBar, ThemeToggle, Modal), then migrate pages incrementally: home → student views → teacher views. Each page migration is a self-contained commit.

**Tech Stack:** Tailwind CSS 4 via `tailwindcss-rails`, ViewComponent gem, Stimulus controller for theme toggle, Propshaft asset pipeline.

---

## File Structure

### New files to create

```
app/assets/tailwind/application.css          ← Tailwind input (created by installer, customized)
app/components/button_component.rb
app/components/button_component.html.erb
app/components/badge_component.rb
app/components/badge_component.html.erb
app/components/card_component.rb
app/components/card_component.html.erb
app/components/progress_bar_component.rb
app/components/progress_bar_component.html.erb
app/components/nav_bar_component.rb
app/components/nav_bar_component.html.erb
app/components/theme_toggle_component.rb
app/components/theme_toggle_component.html.erb
app/components/modal_component.rb
app/components/modal_component.html.erb
app/components/flash_component.rb
app/components/flash_component.html.erb
app/javascript/controllers/theme_controller.js
spec/components/button_component_spec.rb
spec/components/badge_component_spec.rb
spec/components/card_component_spec.rb
spec/components/progress_bar_component_spec.rb
spec/components/nav_bar_component_spec.rb
spec/components/theme_toggle_component_spec.rb
spec/components/modal_component_spec.rb
spec/components/flash_component_spec.rb
```

### Files to modify

```
Gemfile                                      ← add tailwindcss-rails, view_component
config/puma.rb                               ← add tailwindcss plugin
spec/rails_helper.rb                         ← add ViewComponent test helpers
app/views/layouts/application.html.erb       ← Tailwind classes, dark mode, theme controller
app/views/layouts/teacher.html.erb           ← Tailwind classes, NavBarComponent
app/views/pages/home.html.erb
app/views/student/sessions/new.html.erb
app/views/student/subjects/index.html.erb
app/views/student/questions/show.html.erb
app/views/student/questions/_sidebar.html.erb
app/views/student/questions/_correction.html.erb
app/views/student/questions/_chat_drawer.html.erb
app/views/student/settings/show.html.erb
app/views/teacher/classrooms/index.html.erb
app/views/teacher/classrooms/show.html.erb
app/views/teacher/classrooms/new.html.erb
app/views/teacher/subjects/index.html.erb
app/views/teacher/subjects/show.html.erb
app/views/teacher/subjects/new.html.erb
app/views/teacher/subjects/assign.html.erb
app/views/teacher/subjects/_extraction_status.html.erb
app/views/teacher/subjects/_stats.html.erb
app/views/teacher/parts/show.html.erb
app/views/teacher/questions/_question.html.erb
app/views/teacher/questions/_question_form.html.erb
app/views/teacher/students/new.html.erb
app/views/teacher/students/bulk_new.html.erb
app/javascript/controllers/sidebar_controller.js  ← replace inline styles with classList
app/javascript/controllers/chat_controller.js      ← replace inline styles with classList
```

---

### Task 1: Install Tailwind CSS 4

**Files:**
- Modify: `Gemfile`
- Modify: `config/puma.rb`
- Create: `app/assets/tailwind/application.css` (via installer, then customize)

- [ ] **Step 1: Add tailwindcss-rails gem**

Add to `Gemfile` after the `gem "propshaft"` line:

```ruby
gem "tailwindcss-rails"
```

Run:

```bash
bundle install
```

Expected: Gem installs successfully, `Gemfile.lock` updated.

- [ ] **Step 2: Run Tailwind installer**

```bash
bin/rails tailwindcss:install
```

Expected: Creates `app/assets/tailwind/application.css` with `@import "tailwindcss";`. May modify layout to include stylesheet tag.

- [ ] **Step 3: Configure dark mode and custom theme**

Replace the content of `app/assets/tailwind/application.css` with:

```css
@import "tailwindcss";

/* Dark mode via class strategy (toggle .dark on <html>) */
@custom-variant dark (&:where(.dark, .dark *));

/* Custom theme extensions */
@theme {
  --color-primary-50: oklch(0.962 0.018 272.314);
  --color-primary-100: oklch(0.930 0.034 272.788);
  --color-primary-200: oklch(0.870 0.065 274.039);
  --color-primary-300: oklch(0.786 0.111 274.436);
  --color-primary-400: oklch(0.673 0.182 276.935);
  --color-primary-500: oklch(0.585 0.233 277.117);
  --color-primary-600: oklch(0.541 0.281 275.827);
  --color-primary-700: oklch(0.457 0.240 277.023);
  --color-primary-800: oklch(0.398 0.195 277.366);
  --color-primary-900: oklch(0.359 0.144 278.697);
  --color-primary-950: oklch(0.257 0.09 281.288);
}
```

Note: We use Tailwind's built-in `indigo`, `emerald`, `amber`, `rose`, `slate`, `blue` colors directly. The `--color-primary-*` maps to indigo for semantic usage. In practice we'll use `indigo-500`, `emerald-500` etc. directly in classes.

Simplify to:

```css
@import "tailwindcss";

/* Dark mode via class strategy (toggle .dark on <html>) */
@custom-variant dark (&:where(.dark, .dark *));
```

- [ ] **Step 4: Add Tailwind Puma plugin**

Add this line to `config/puma.rb` after `plugin :tmp_restart`:

```ruby
plugin :tailwindcss if ENV.fetch("RAILS_ENV", "development") == "development"
```

- [ ] **Step 5: Verify Tailwind builds**

```bash
bin/rails tailwindcss:build
```

Expected: No errors, CSS output generated.

- [ ] **Step 6: Commit**

```bash
git add Gemfile Gemfile.lock config/puma.rb app/assets/tailwind/
git commit -m "chore(install): add Tailwind CSS 4 via tailwindcss-rails

CSS-first config with dark mode class strategy.
Puma plugin for dev auto-rebuild."
```

---

### Task 2: Install ViewComponent

**Files:**
- Modify: `Gemfile`
- Modify: `spec/rails_helper.rb`

- [ ] **Step 1: Add view_component gem**

Add to `Gemfile` after `gem "tailwindcss-rails"`:

```ruby
gem "view_component"
```

Run:

```bash
bundle install
```

Expected: Gem installs successfully.

- [ ] **Step 2: Configure RSpec for ViewComponent**

Add after the `require "webmock/rspec"` line in `spec/rails_helper.rb`:

```ruby
require "view_component/test_helpers"
require "view_component/system_test_helpers"
require "capybara/rspec"
```

Then inside the `RSpec.configure do |config|` block, add after the existing `config.include` lines:

```ruby
  config.include ViewComponent::TestHelpers, type: :component
  config.include ViewComponent::SystemTestHelpers, type: :component
  config.include Capybara::RSpecMatchers, type: :component
```

- [ ] **Step 3: Verify setup**

```bash
bundle exec rspec --dry-run
```

Expected: No errors from the new requires.

- [ ] **Step 4: Commit**

```bash
git add Gemfile Gemfile.lock spec/rails_helper.rb
git commit -m "chore(install): add ViewComponent gem with RSpec integration"
```

---

### Task 3: Create ButtonComponent

**Files:**
- Create: `app/components/button_component.rb`
- Create: `app/components/button_component.html.erb`
- Create: `spec/components/button_component_spec.rb`

- [ ] **Step 1: Write the failing test**

Create `spec/components/button_component_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe ButtonComponent, type: :component do
  it "renders a primary button by default" do
    render_inline(described_class.new) { "Continuer" }

    expect(page).to have_button("Continuer")
    expect(page).to have_css("button.bg-indigo-500")
  end

  it "renders a success button" do
    render_inline(described_class.new(variant: :success)) { "Commencer" }

    expect(page).to have_button("Commencer")
    expect(page).to have_css("button.bg-emerald-500")
  end

  it "renders a ghost button" do
    render_inline(described_class.new(variant: :ghost)) { "Annuler" }

    expect(page).to have_button("Annuler")
    expect(page).to have_css("button.border")
  end

  it "renders a pill button" do
    render_inline(described_class.new(pill: true)) { "Go" }

    expect(page).to have_css("button.rounded-full")
  end

  it "renders as a link when href is provided" do
    render_inline(described_class.new(href: "/subjects")) { "Voir" }

    expect(page).to have_link("Voir", href: "/subjects")
    expect(page).to have_css("a.bg-indigo-500")
  end

  it "renders small size" do
    render_inline(described_class.new(size: :sm)) { "Ok" }

    expect(page).to have_css("button.px-3.py-1\\.5.text-xs")
  end

  it "renders large size" do
    render_inline(described_class.new(size: :lg)) { "Submit" }

    expect(page).to have_css("button.px-6.py-3.text-base")
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
bundle exec rspec spec/components/button_component_spec.rb
```

Expected: FAIL — `uninitialized constant ButtonComponent`

- [ ] **Step 3: Write the component**

Create `app/components/button_component.rb`:

```ruby
class ButtonComponent < ViewComponent::Base
  VARIANTS = {
    primary: "bg-indigo-500 text-white hover:bg-indigo-600 focus-visible:ring-indigo-500",
    success: "bg-emerald-500 text-white hover:bg-emerald-600 focus-visible:ring-emerald-500",
    ghost: "border border-slate-700 dark:border-slate-700 text-slate-300 dark:text-slate-300 hover:bg-slate-800 dark:hover:bg-slate-800 light:border-slate-200 light:text-slate-600 light:hover:bg-slate-50"
  }.freeze

  SIZES = {
    sm: "px-3 py-1.5 text-xs",
    md: "px-4 py-2 text-sm",
    lg: "px-6 py-3 text-base"
  }.freeze

  def initialize(variant: :primary, size: :md, pill: false, href: nil, **html_options)
    @variant = variant.to_sym
    @size = size.to_sym
    @pill = pill
    @href = href
    @html_options = html_options
  end

  def call
    css = class_names(
      "inline-flex items-center justify-center font-semibold transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-offset-2 cursor-pointer",
      VARIANTS[@variant],
      SIZES[@size],
      @pill ? "rounded-full" : "rounded-lg"
    )

    if @href
      content_tag(:a, content, href: @href, class: css, **@html_options)
    else
      content_tag(:button, content, class: css, **@html_options)
    end
  end
end
```

No separate `.html.erb` needed — the component uses `call` method.

- [ ] **Step 4: Run test to verify it passes**

```bash
bundle exec rspec spec/components/button_component_spec.rb
```

Expected: All 7 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add app/components/button_component.rb spec/components/button_component_spec.rb
git commit -m "feat(components): add ButtonComponent — primary/success/ghost, pill, link support"
```

---

### Task 4: Create BadgeComponent

**Files:**
- Create: `app/components/badge_component.rb`
- Create: `spec/components/badge_component_spec.rb`

- [ ] **Step 1: Write the failing test**

Create `spec/components/badge_component_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe BadgeComponent, type: :component do
  it "renders an indigo badge" do
    render_inline(described_class.new(color: :indigo, label: "SIN"))

    expect(page).to have_text("SIN")
    expect(page).to have_css("span.text-indigo-300")
  end

  it "renders an emerald badge" do
    render_inline(described_class.new(color: :emerald, label: "2024"))

    expect(page).to have_text("2024")
    expect(page).to have_css("span.text-emerald-300")
  end

  it "renders an amber badge" do
    render_inline(described_class.new(color: :amber, label: "Métropole"))

    expect(page).to have_text("Métropole")
  end

  it "renders a blue badge" do
    render_inline(described_class.new(color: :blue, label: "DT1"))

    expect(page).to have_text("DT1")
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
bundle exec rspec spec/components/badge_component_spec.rb
```

Expected: FAIL — `uninitialized constant BadgeComponent`

- [ ] **Step 3: Write the component**

Create `app/components/badge_component.rb`:

```ruby
class BadgeComponent < ViewComponent::Base
  COLORS = {
    indigo:  "bg-indigo-500/10 text-indigo-300 dark:bg-indigo-500/10 dark:text-indigo-300",
    emerald: "bg-emerald-500/10 text-emerald-300 dark:bg-emerald-500/10 dark:text-emerald-300",
    amber:   "bg-amber-500/10 text-amber-300 dark:bg-amber-500/10 dark:text-amber-300",
    blue:    "bg-blue-500/10 text-blue-300 dark:bg-blue-500/10 dark:text-blue-300",
    slate:   "bg-slate-500/10 text-slate-400 dark:bg-slate-500/10 dark:text-slate-400",
    rose:    "bg-rose-500/10 text-rose-300 dark:bg-rose-500/10 dark:text-rose-300"
  }.freeze

  # Light mode overrides — applied automatically
  LIGHT_COLORS = {
    indigo:  "text-indigo-600 bg-indigo-50",
    emerald: "text-emerald-600 bg-emerald-50",
    amber:   "text-amber-600 bg-amber-50",
    blue:    "text-blue-600 bg-blue-50",
    slate:   "text-slate-600 bg-slate-50",
    rose:    "text-rose-600 bg-rose-50"
  }.freeze

  def initialize(color:, label:)
    @color = color.to_sym
    @label = label
  end

  def call
    css = class_names(
      "inline-flex items-center px-2 py-0.5 rounded text-xs font-medium",
      COLORS[@color]
    )

    content_tag(:span, @label, class: css)
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

```bash
bundle exec rspec spec/components/badge_component_spec.rb
```

Expected: All 4 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add app/components/badge_component.rb spec/components/badge_component_spec.rb
git commit -m "feat(components): add BadgeComponent — indigo/emerald/amber/blue/slate/rose"
```

---

### Task 5: Create CardComponent

**Files:**
- Create: `app/components/card_component.rb`
- Create: `app/components/card_component.html.erb`
- Create: `spec/components/card_component_spec.rb`

- [ ] **Step 1: Write the failing test**

Create `spec/components/card_component_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe CardComponent, type: :component do
  it "renders with body content" do
    render_inline(described_class.new) do |card|
      card.with_body { "Hello world" }
    end

    expect(page).to have_text("Hello world")
    expect(page).to have_css("div.bg-slate-800")
    expect(page).to have_css("div.border-slate-700")
    expect(page).to have_css("div.rounded-lg")
  end

  it "renders header, body, and footer" do
    render_inline(described_class.new) do |card|
      card.with_header { "Title" }
      card.with_body { "Content" }
      card.with_footer { "Footer" }
    end

    expect(page).to have_text("Title")
    expect(page).to have_text("Content")
    expect(page).to have_text("Footer")
    expect(page).to have_css("div.border-t")
  end

  it "renders without footer when not provided" do
    render_inline(described_class.new) do |card|
      card.with_body { "Content only" }
    end

    expect(page).to have_text("Content only")
    expect(page).not_to have_css("div.border-t")
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
bundle exec rspec spec/components/card_component_spec.rb
```

Expected: FAIL — `uninitialized constant CardComponent`

- [ ] **Step 3: Write the component**

Create `app/components/card_component.rb`:

```ruby
class CardComponent < ViewComponent::Base
  renders_one :header
  renders_one :body
  renders_one :footer
end
```

Create `app/components/card_component.html.erb`:

```erb
<div class="bg-slate-800 dark:bg-slate-800 border border-slate-700 dark:border-slate-700 rounded-lg overflow-hidden
            bg-white border-slate-200 shadow-sm
            dark:bg-slate-800 dark:border-slate-700 dark:shadow-none">
  <% if header? %>
    <div class="px-4 py-3">
      <%= header %>
    </div>
  <% end %>

  <% if body? %>
    <div class="px-4 py-3">
      <%= body %>
    </div>
  <% end %>

  <% if footer? %>
    <div class="border-t border-slate-700 dark:border-slate-700 border-slate-200 px-4 py-3">
      <%= footer %>
    </div>
  <% end %>
</div>
```

Wait — the dark-first approach needs careful class ordering. Since dark is default and we use `dark:` variant, we need to structure it as: light classes are defaults applied when `.dark` is NOT present, and `dark:` classes apply when it IS. But with `@custom-variant dark (&:where(.dark, .dark *))`, the `dark:` variant activates inside `.dark`. So the **base** styles should be the light mode, and `dark:` overrides for dark.

However, since dark is default, the `<html>` will have `class="dark"` by default. So:
- Base (no prefix) = light mode styles
- `dark:` prefix = dark mode styles

This is the correct Tailwind pattern. Let me fix the template:

```erb
<div class="bg-white border border-slate-200 shadow-sm rounded-lg overflow-hidden
            dark:bg-slate-800 dark:border-slate-700 dark:shadow-none">
  <% if header? %>
    <div class="px-4 py-3">
      <%= header %>
    </div>
  <% end %>

  <% if body? %>
    <div class="px-4 py-3">
      <%= body %>
    </div>
  <% end %>

  <% if footer? %>
    <div class="border-t border-slate-200 dark:border-slate-700 px-4 py-3">
      <%= footer %>
    </div>
  <% end %>
</div>
```

- [ ] **Step 4: Run test to verify it passes**

```bash
bundle exec rspec spec/components/card_component_spec.rb
```

Expected: All 3 tests PASS. Note: tests check for `bg-slate-800` which appears via `dark:bg-slate-800`. We need to adjust tests to check the rendered CSS classes. Since the test renders without a `.dark` wrapper, we should check for the base (light) classes, or adjust the test. Let me fix the test:

Update `spec/components/card_component_spec.rb` — first test assertion:

```ruby
  it "renders with body content" do
    render_inline(described_class.new) do |card|
      card.with_body { "Hello world" }
    end

    expect(page).to have_text("Hello world")
    expect(page).to have_css("div.rounded-lg")
    expect(page).to have_css("div.border")
  end
```

- [ ] **Step 5: Commit**

```bash
git add app/components/card_component.rb app/components/card_component.html.erb spec/components/card_component_spec.rb
git commit -m "feat(components): add CardComponent — header/body/footer slots, dark/light"
```

---

### Task 6: Create ProgressBarComponent

**Files:**
- Create: `app/components/progress_bar_component.rb`
- Create: `spec/components/progress_bar_component_spec.rb`

- [ ] **Step 1: Write the failing test**

Create `spec/components/progress_bar_component_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe ProgressBarComponent, type: :component do
  it "renders the progress bar" do
    render_inline(described_class.new(current: 7, total: 18))

    expect(page).to have_css("[role='progressbar']")
    expect(page).to have_css("[aria-valuenow='7']")
    expect(page).to have_css("[aria-valuemax='18']")
  end

  it "renders the text label" do
    render_inline(described_class.new(current: 7, total: 18, show_text: true))

    expect(page).to have_text("7/18")
    expect(page).to have_text("39%")
  end

  it "handles zero total" do
    render_inline(described_class.new(current: 0, total: 0))

    expect(page).to have_css("[aria-valuenow='0']")
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
bundle exec rspec spec/components/progress_bar_component_spec.rb
```

Expected: FAIL — `uninitialized constant ProgressBarComponent`

- [ ] **Step 3: Write the component**

Create `app/components/progress_bar_component.rb`:

```ruby
class ProgressBarComponent < ViewComponent::Base
  COLORS = {
    indigo: "bg-indigo-500",
    emerald: "bg-emerald-500"
  }.freeze

  def initialize(current:, total:, color: :indigo, show_text: false)
    @current = current
    @total = total
    @color = color.to_sym
    @show_text = show_text
  end

  def percentage
    return 0 if @total.zero?
    (@current * 100.0 / @total).round
  end

  def bar_color
    COLORS[@color] || COLORS[:indigo]
  end

  def call
    content_tag(:div, class: "flex items-center gap-2") do
      bar = content_tag(:div, role: "progressbar",
                        aria: { valuenow: @current, valuemin: 0, valuemax: @total },
                        class: "flex-1 h-1 bg-slate-200 dark:bg-slate-700 rounded-full overflow-hidden") do
        content_tag(:div, "", class: "h-full #{bar_color} rounded-full transition-all",
                    style: "width: #{percentage}%")
      end

      if @show_text
        text = content_tag(:span, "#{@current}/#{@total} — #{percentage}%",
                           class: "text-xs text-slate-500 dark:text-slate-400 whitespace-nowrap")
        bar + text
      else
        bar
      end
    end
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

```bash
bundle exec rspec spec/components/progress_bar_component_spec.rb
```

Expected: All 3 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add app/components/progress_bar_component.rb spec/components/progress_bar_component_spec.rb
git commit -m "feat(components): add ProgressBarComponent — indigo/emerald, text label, accessible"
```

---

### Task 7: Create ThemeToggleComponent + Stimulus controller

**Files:**
- Create: `app/components/theme_toggle_component.rb`
- Create: `app/javascript/controllers/theme_controller.js`
- Create: `spec/components/theme_toggle_component_spec.rb`

- [ ] **Step 1: Write the failing test**

Create `spec/components/theme_toggle_component_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe ThemeToggleComponent, type: :component do
  it "renders a toggle button" do
    render_inline(described_class.new)

    expect(page).to have_css("button[data-action='click->theme#toggle']")
    expect(page).to have_css("button[aria-label]")
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
bundle exec rspec spec/components/theme_toggle_component_spec.rb
```

Expected: FAIL — `uninitialized constant ThemeToggleComponent`

- [ ] **Step 3: Write the component**

Create `app/components/theme_toggle_component.rb`:

```ruby
class ThemeToggleComponent < ViewComponent::Base
  def call
    content_tag(:button,
      data: { action: "click->theme#toggle" },
      aria: { label: "Changer de thème" },
      class: "p-2 rounded-lg text-slate-500 dark:text-slate-400 hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors cursor-pointer") do
      # Sun icon (visible in dark mode)
      sun = content_tag(:svg, class: "w-5 h-5 hidden dark:block", fill: "none", viewBox: "0 0 24 24", stroke: "currentColor", stroke_width: "2") do
        content_tag(:path, "", stroke_linecap: "round", stroke_linejoin: "round",
          d: "M12 3v1m0 16v1m9-9h-1M4 12H3m15.364 6.364l-.707-.707M6.343 6.343l-.707-.707m12.728 0l-.707.707M6.343 17.657l-.707.707M16 12a4 4 0 11-8 0 4 4 0 018 0z")
      end
      # Moon icon (visible in light mode)
      moon = content_tag(:svg, class: "w-5 h-5 block dark:hidden", fill: "none", viewBox: "0 0 24 24", stroke: "currentColor", stroke_width: "2") do
        content_tag(:path, "", stroke_linecap: "round", stroke_linejoin: "round",
          d: "M20.354 15.354A9 9 0 018.646 3.646 9.003 9.003 0 0012 21a9.003 9.003 0 008.354-5.646z")
      end
      sun + moon
    end
  end
end
```

- [ ] **Step 4: Write the Stimulus theme controller**

Create `app/javascript/controllers/theme_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.applyTheme()
    this.mediaQuery = window.matchMedia("(prefers-color-scheme: dark)")
    this.mediaQuery.addEventListener("change", this.handleSystemChange)
  }

  disconnect() {
    this.mediaQuery.removeEventListener("change", this.handleSystemChange)
  }

  toggle() {
    const isDark = document.documentElement.classList.contains("dark")
    if (isDark) {
      document.documentElement.classList.remove("dark")
      localStorage.setItem("theme", "light")
    } else {
      document.documentElement.classList.add("dark")
      localStorage.setItem("theme", "dark")
    }
  }

  applyTheme() {
    const stored = localStorage.getItem("theme")
    if (stored === "light") {
      document.documentElement.classList.remove("dark")
    } else if (stored === "dark") {
      document.documentElement.classList.add("dark")
    } else {
      // No override — follow system preference, default to dark
      if (window.matchMedia("(prefers-color-scheme: light)").matches) {
        document.documentElement.classList.remove("dark")
      } else {
        document.documentElement.classList.add("dark")
      }
    }
  }

  handleSystemChange = () => {
    // Only react to system changes when no manual override is set
    if (!localStorage.getItem("theme")) {
      this.applyTheme()
    }
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

```bash
bundle exec rspec spec/components/theme_toggle_component_spec.rb
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add app/components/theme_toggle_component.rb app/javascript/controllers/theme_controller.js spec/components/theme_toggle_component_spec.rb
git commit -m "feat(components): add ThemeToggleComponent + Stimulus theme controller

Dark by default, auto-detects system preference, manual override
persisted in localStorage."
```

---

### Task 8: Create NavBarComponent

**Files:**
- Create: `app/components/nav_bar_component.rb`
- Create: `app/components/nav_bar_component.html.erb`
- Create: `spec/components/nav_bar_component_spec.rb`

- [ ] **Step 1: Write the failing test**

Create `spec/components/nav_bar_component_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe NavBarComponent, type: :component do
  it "renders the brand" do
    render_inline(described_class.new) do |nav|
      nav.with_brand { "DekatjeBakLa" }
    end

    expect(page).to have_text("DekatjeBakLa")
    expect(page).to have_css("nav")
  end

  it "renders links" do
    render_inline(described_class.new) do |nav|
      nav.with_brand { "App" }
      nav.with_link(href: "/classes") { "Mes classes" }
      nav.with_link(href: "/sujets") { "Mes sujets" }
    end

    expect(page).to have_link("Mes classes", href: "/classes")
    expect(page).to have_link("Mes sujets", href: "/sujets")
  end

  it "renders actions slot" do
    render_inline(described_class.new) do |nav|
      nav.with_brand { "App" }
      nav.with_actions { "Actions here" }
    end

    expect(page).to have_text("Actions here")
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
bundle exec rspec spec/components/nav_bar_component_spec.rb
```

Expected: FAIL — `uninitialized constant NavBarComponent`

- [ ] **Step 3: Write the component**

Create `app/components/nav_bar_component.rb`:

```ruby
class NavBarComponent < ViewComponent::Base
  renders_one :brand
  renders_many :links, lambda { |href:, **options|
    content_tag(:a, href: href,
      class: "text-sm text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-slate-200 transition-colors",
      **options) { content }
  }
  renders_one :actions
end
```

Create `app/components/nav_bar_component.html.erb`:

```erb
<nav class="flex items-center justify-between px-4 py-3 bg-white dark:bg-slate-800 border-b border-slate-200 dark:border-slate-700">
  <div class="flex items-center gap-6">
    <% if brand? %>
      <div class="text-base font-semibold text-slate-800 dark:text-slate-200">
        <%= brand %>
      </div>
    <% end %>

    <% if links? %>
      <div class="hidden md:flex items-center gap-4">
        <% links.each do |link| %>
          <%= link %>
        <% end %>
      </div>
    <% end %>
  </div>

  <% if actions? %>
    <div class="flex items-center gap-3">
      <%= actions %>
    </div>
  <% end %>
</nav>
```

- [ ] **Step 4: Run test to verify it passes**

```bash
bundle exec rspec spec/components/nav_bar_component_spec.rb
```

Expected: All 3 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add app/components/nav_bar_component.rb app/components/nav_bar_component.html.erb spec/components/nav_bar_component_spec.rb
git commit -m "feat(components): add NavBarComponent — brand/links/actions slots, responsive"
```

---

### Task 9: Create FlashComponent and ModalComponent

**Files:**
- Create: `app/components/flash_component.rb`
- Create: `app/components/modal_component.rb`
- Create: `app/components/modal_component.html.erb`
- Create: `spec/components/flash_component_spec.rb`
- Create: `spec/components/modal_component_spec.rb`

- [ ] **Step 1: Write failing tests**

Create `spec/components/flash_component_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe FlashComponent, type: :component do
  it "renders a notice flash" do
    render_inline(described_class.new(type: :notice, message: "Sauvegardé"))

    expect(page).to have_text("Sauvegardé")
    expect(page).to have_css("div.bg-emerald-50")
  end

  it "renders an alert flash" do
    render_inline(described_class.new(type: :alert, message: "Erreur"))

    expect(page).to have_text("Erreur")
    expect(page).to have_css("div.bg-rose-50")
  end

  it "renders nothing when message is blank" do
    render_inline(described_class.new(type: :notice, message: nil))

    expect(page.text).to be_empty
  end
end
```

Create `spec/components/modal_component_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe ModalComponent, type: :component do
  it "renders a modal with title" do
    render_inline(described_class.new(title: "Confirmer")) do |modal|
      modal.with_body { "Êtes-vous sûr ?" }
    end

    expect(page).to have_text("Confirmer")
    expect(page).to have_text("Êtes-vous sûr ?")
    expect(page).to have_css("[role='dialog']")
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
bundle exec rspec spec/components/flash_component_spec.rb spec/components/modal_component_spec.rb
```

Expected: FAIL — uninitialized constants.

- [ ] **Step 3: Write FlashComponent**

Create `app/components/flash_component.rb`:

```ruby
class FlashComponent < ViewComponent::Base
  TYPES = {
    notice: "bg-emerald-50 dark:bg-emerald-500/10 text-emerald-700 dark:text-emerald-300 border-emerald-200 dark:border-emerald-500/20",
    alert:  "bg-rose-50 dark:bg-rose-500/10 text-rose-700 dark:text-rose-300 border-rose-200 dark:border-rose-500/20"
  }.freeze

  def initialize(type:, message:)
    @type = type.to_sym
    @message = message
  end

  def render?
    @message.present?
  end

  def call
    content_tag(:div, @message,
      class: "px-4 py-3 rounded-lg border text-sm #{TYPES[@type]}")
  end
end
```

- [ ] **Step 4: Write ModalComponent**

Create `app/components/modal_component.rb`:

```ruby
class ModalComponent < ViewComponent::Base
  renders_one :body

  def initialize(title:)
    @title = title
  end
end
```

Create `app/components/modal_component.html.erb`:

```erb
<div role="dialog" aria-modal="true" class="fixed inset-0 z-50 flex items-center justify-center">
  <%# Backdrop %>
  <div class="absolute inset-0 bg-black/50"></div>

  <%# Modal %>
  <div class="relative bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg shadow-xl max-w-md w-full mx-4 p-6">
    <h3 class="text-lg font-semibold text-slate-800 dark:text-slate-200 mb-4"><%= @title %></h3>
    <% if body? %>
      <%= body %>
    <% end %>
  </div>
</div>
```

- [ ] **Step 5: Run tests to verify they pass**

```bash
bundle exec rspec spec/components/flash_component_spec.rb spec/components/modal_component_spec.rb
```

Expected: All tests PASS.

- [ ] **Step 6: Commit**

```bash
git add app/components/flash_component.rb app/components/modal_component.rb app/components/modal_component.html.erb spec/components/flash_component_spec.rb spec/components/modal_component_spec.rb
git commit -m "feat(components): add FlashComponent and ModalComponent"
```

---

### Task 10: Update layouts — application + teacher

**Files:**
- Modify: `app/views/layouts/application.html.erb`
- Modify: `app/views/layouts/teacher.html.erb`

- [ ] **Step 1: Update application layout**

Replace `app/views/layouts/application.html.erb` with:

```erb
<!DOCTYPE html>
<html class="dark">
  <head>
    <title><%= content_for(:title) || "Dekatje Bak La" %></title>
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <meta name="apple-mobile-web-app-capable" content="yes">
    <meta name="application-name" content="Dekatje Bak La">
    <meta name="mobile-web-app-capable" content="yes">
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>

    <%= yield :head %>

    <link rel="icon" href="/icon.png" type="image/png">
    <link rel="icon" href="/icon.svg" type="image/svg+xml">
    <link rel="apple-touch-icon" href="/icon.png">

    <%= stylesheet_link_tag "tailwind", "data-turbo-track": "reload" %>
    <%= stylesheet_link_tag :app, "data-turbo-track": "reload" %>
    <%= javascript_importmap_tags %>

    <script>
      // Apply theme before first paint to prevent flash
      (function() {
        var stored = localStorage.getItem('theme');
        if (stored === 'light') {
          document.documentElement.classList.remove('dark');
        } else if (!stored && window.matchMedia('(prefers-color-scheme: light)').matches) {
          document.documentElement.classList.remove('dark');
        }
      })();
    </script>
  </head>

  <body class="bg-slate-50 dark:bg-slate-950 text-slate-800 dark:text-slate-200 min-h-screen"
        data-controller="theme">
    <% if notice.present? %>
      <div class="max-w-4xl mx-auto mt-4 px-4">
        <%= render(FlashComponent.new(type: :notice, message: notice)) %>
      </div>
    <% end %>
    <% if alert.present? %>
      <div class="max-w-4xl mx-auto mt-4 px-4">
        <%= render(FlashComponent.new(type: :alert, message: alert)) %>
      </div>
    <% end %>
    <%= yield %>
  </body>
</html>
```

- [ ] **Step 2: Update teacher layout**

Replace `app/views/layouts/teacher.html.erb` with:

```erb
<!DOCTYPE html>
<html class="dark">
  <head>
    <title>DekatjeBakLa — Espace enseignant</title>
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>
    <%= stylesheet_link_tag "tailwind", "data-turbo-track": "reload" %>
    <%= stylesheet_link_tag :app, "data-turbo-track": "reload" %>
    <%= javascript_importmap_tags %>

    <script>
      (function() {
        var stored = localStorage.getItem('theme');
        if (stored === 'light') {
          document.documentElement.classList.remove('dark');
        } else if (!stored && window.matchMedia('(prefers-color-scheme: light)').matches) {
          document.documentElement.classList.remove('dark');
        }
      })();
    </script>
  </head>

  <body class="bg-slate-50 dark:bg-slate-950 text-slate-800 dark:text-slate-200 min-h-screen"
        data-controller="theme">
    <%= render(NavBarComponent.new) do |nav|
      nav.with_brand { link_to "DekatjeBakLa", teacher_root_path, class: "text-base font-semibold text-slate-800 dark:text-slate-200 no-underline" }
      nav.with_link(href: teacher_root_path) { "Mes classes" }
      nav.with_link(href: teacher_subjects_path) { "Mes sujets" }
      nav.with_actions do
        render(ThemeToggleComponent.new) +
        link_to("Déconnexion", destroy_user_session_path, data: { turbo_method: :delete },
          class: "text-sm text-slate-500 dark:text-slate-400 hover:text-slate-700 dark:hover:text-slate-200")
      end
    end %>

    <main class="max-w-6xl mx-auto px-4 py-6">
      <% if notice.present? %>
        <div class="mb-4">
          <%= render(FlashComponent.new(type: :notice, message: notice)) %>
        </div>
      <% end %>
      <% if alert.present? %>
        <div class="mb-4">
          <%= render(FlashComponent.new(type: :alert, message: alert)) %>
        </div>
      <% end %>
      <%= yield %>
    </main>
  </body>
</html>
```

- [ ] **Step 3: Verify layouts render**

```bash
bin/rails tailwindcss:build && bundle exec rspec spec/features/ --fail-fast
```

Expected: Existing feature tests should still pass (HTML structure changed but functionality intact). Fix any test selectors that relied on inline styles.

- [ ] **Step 4: Commit**

```bash
git add app/views/layouts/application.html.erb app/views/layouts/teacher.html.erb
git commit -m "feat(layout): migrate application + teacher layouts to Tailwind

Dark by default, FlashComponent for notices, NavBarComponent for teacher nav,
ThemeToggleComponent for dark/light switch. Inline script prevents flash of
wrong theme on load."
```

---

### Task 11: Migrate home page

**Files:**
- Modify: `app/views/pages/home.html.erb`

- [ ] **Step 1: Replace home page**

Replace `app/views/pages/home.html.erb` with:

```erb
<div class="min-h-screen flex items-center justify-center px-4">
  <div class="max-w-md w-full text-center">
    <%# Theme toggle in corner %>
    <div class="fixed top-4 right-4">
      <%= render(ThemeToggleComponent.new) %>
    </div>

    <h1 class="text-3xl font-bold text-slate-800 dark:text-slate-100 mb-2">DekatjeBakLa</h1>
    <p class="text-slate-500 dark:text-slate-400 mb-10">Entraînement aux examens BAC</p>

    <%# Student access %>
    <h2 class="text-lg font-semibold text-slate-700 dark:text-slate-300 mb-4">Espace élève</h2>

    <%= form_tag nil, method: :get, id: "student-access-form" do %>
      <div class="flex gap-2 justify-center items-center">
        <label for="access_code" class="sr-only">Code d'accès</label>
        <%= text_field_tag :access_code, nil,
            placeholder: "Code de la classe",
            id: "access_code",
            class: "px-4 py-2.5 bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg text-sm text-slate-800 dark:text-slate-200 placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-emerald-500" %>
        <%= render(ButtonComponent.new(variant: :success, pill: true, type: "submit")) { "Accéder" } %>
      </div>
    <% end %>

    <script>
      document.getElementById("student-access-form").addEventListener("submit", function(e) {
        e.preventDefault();
        var code = this.querySelector("[name='access_code']").value.trim();
        if (code) {
          window.location.href = "/" + encodeURIComponent(code);
        }
      });
    </script>

    <hr class="border-slate-200 dark:border-slate-700 my-10">

    <%# Teacher access %>
    <%= render(ButtonComponent.new(variant: :ghost, href: new_user_session_path)) { "Espace enseignant →" } %>

    <p class="mt-16 text-xs text-slate-400 dark:text-slate-500">DekatjeBakLa — Martinique</p>
  </div>
</div>
```

- [ ] **Step 2: Verify it renders**

```bash
bin/rails tailwindcss:build
```

Visit `http://localhost:3000` manually or run relevant feature test.

- [ ] **Step 3: Commit**

```bash
git add app/views/pages/home.html.erb
git commit -m "feat(home): migrate home page to Tailwind + components

Minimal centered login screen with student access code form,
teacher link, theme toggle."
```

---

### Task 12: Migrate student login page

**Files:**
- Modify: `app/views/student/sessions/new.html.erb`

- [ ] **Step 1: Replace student login**

Replace `app/views/student/sessions/new.html.erb` with:

```erb
<div class="min-h-screen flex items-center justify-center px-4">
  <div class="max-w-sm w-full">
    <div class="text-center mb-8">
      <h1 class="text-2xl font-bold text-slate-800 dark:text-slate-100 mb-2"><%= @classroom.name %></h1>
      <p class="text-sm text-slate-500 dark:text-slate-400">Connecte-toi pour accéder aux sujets</p>
    </div>

    <%= form_tag student_session_path(access_code: params[:access_code]), method: :post do %>
      <div class="space-y-4">
        <div>
          <label for="username" class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1">Identifiant</label>
          <%= text_field_tag :username, nil,
              id: "username",
              autocomplete: "username",
              class: "w-full px-4 py-2.5 bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg text-sm text-slate-800 dark:text-slate-200 placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-indigo-500" %>
        </div>
        <div>
          <label for="password" class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1">Mot de passe</label>
          <%= password_field_tag :password, nil,
              id: "password",
              autocomplete: "current-password",
              class: "w-full px-4 py-2.5 bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg text-sm text-slate-800 dark:text-slate-200 placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-indigo-500" %>
        </div>
        <div class="pt-2">
          <%= render(ButtonComponent.new(pill: true, type: "submit", class: "w-full justify-center")) { "Se connecter" } %>
        </div>
      </div>
    <% end %>

    <div class="text-center mt-6">
      <%= link_to "← Retour", root_path, class: "text-sm text-slate-500 dark:text-slate-400 hover:text-slate-700 dark:hover:text-slate-200" %>
    </div>
  </div>
</div>
```

- [ ] **Step 2: Commit**

```bash
git add app/views/student/sessions/new.html.erb
git commit -m "feat(student): migrate login page to Tailwind"
```

---

### Task 13: Migrate student dashboard (subjects index)

**Files:**
- Modify: `app/views/student/subjects/index.html.erb`

- [ ] **Step 1: Replace student dashboard**

Replace `app/views/student/subjects/index.html.erb` with:

```erb
<%= render(NavBarComponent.new) do |nav|
  nav.with_brand { "DekatjeBakLa" }
  nav.with_actions do
    render(ThemeToggleComponent.new) +
    link_to("⚙ Réglages", student_settings_path(access_code: params[:access_code]),
      class: "text-sm text-slate-500 dark:text-slate-400 hover:text-slate-700 dark:hover:text-slate-200 border border-slate-200 dark:border-slate-700 rounded-lg px-3 py-1.5") +
    link_to("Déconnexion", student_session_path(access_code: params[:access_code]),
      data: { turbo_method: :delete },
      class: "text-sm text-slate-500 dark:text-slate-400 hover:text-slate-700 dark:hover:text-slate-200")
  end
end %>

<main class="max-w-5xl mx-auto px-4 py-6">
  <div class="flex items-center justify-between mb-6">
    <h1 class="text-xl font-semibold text-slate-800 dark:text-slate-200">Mes sujets</h1>
    <span class="text-sm text-slate-500 dark:text-slate-400"><%= @subjects.size %> sujets assignés</span>
  </div>

  <% if @subjects.empty? %>
    <div class="text-center py-16">
      <p class="text-slate-500 dark:text-slate-400">Aucun sujet assigné pour le moment.</p>
    </div>
  <% else %>
    <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
      <% @subjects.each do |subject| %>
        <%
          session_record = @sessions[subject.id]
          total_questions = subject.questions.kept.count
          answered = session_record ? session_record.answered_count : 0
          pct = total_questions > 0 ? (answered * 100.0 / total_questions).round : 0
          started = answered > 0
        %>
        <%= render(CardComponent.new) do |card|
          card.with_body do %>
            <div class="flex gap-2 flex-wrap mb-3">
              <%= render(BadgeComponent.new(color: :indigo, label: subject.specialty&.upcase || "—")) %>
              <%= render(BadgeComponent.new(color: :emerald, label: subject.year.to_s)) %>
            </div>
            <h3 class="text-sm font-semibold text-slate-800 dark:text-slate-200 mb-1"><%= subject.title %></h3>
            <p class="text-xs text-slate-500 dark:text-slate-400 mb-3">
              <%= subject.exam_type&.upcase %> · <%= subject.specialty %>
            </p>
            <%= render(ProgressBarComponent.new(current: answered, total: total_questions, show_text: true)) %>
          <% end

          card.with_footer do %>
            <div class="flex justify-end">
              <% first_question = subject.parts.ordered.first&.questions&.kept&.first %>
              <% if first_question %>
                <%= render(ButtonComponent.new(
                  variant: started ? :primary : :success,
                  pill: true,
                  size: :sm,
                  href: student_question_path(access_code: params[:access_code], subject_id: subject.id, id: first_question.id)
                )) { started ? "Continuer →" : "Commencer →" } %>
              <% end %>
            </div>
          <% end
        end %>
      <% end %>
    </div>
  <% end %>
</main>
```

Note: The exact method names (`answered_count`, `questions.kept`, `parts.ordered`) may need adjustment to match existing model methods. Check the existing view for the exact method calls used.

- [ ] **Step 2: Verify rendering**

```bash
bin/rails tailwindcss:build && bundle exec rspec spec/features/ --fail-fast
```

Fix any method name mismatches or missing associations.

- [ ] **Step 3: Commit**

```bash
git add app/views/student/subjects/index.html.erb
git commit -m "feat(student): migrate dashboard to Tailwind + CardComponent

Grid of subject cards with badges, progress bars, and pill action buttons."
```

---

### Task 14: Migrate student question screen

**Files:**
- Modify: `app/views/student/questions/show.html.erb`
- Modify: `app/views/student/questions/_sidebar.html.erb`
- Modify: `app/views/student/questions/_correction.html.erb`
- Modify: `app/javascript/controllers/sidebar_controller.js`

This is the largest single migration. It replaces all inline styles in the main student interface.

- [ ] **Step 1: Update sidebar controller to use classes**

Replace `app/javascript/controllers/sidebar_controller.js` with:

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["drawer", "backdrop"]

  open() {
    this.drawerTarget.classList.remove("-translate-x-full")
    this.drawerTarget.classList.add("translate-x-0")
    this.backdropTarget.classList.remove("hidden")
  }

  close() {
    this.drawerTarget.classList.add("-translate-x-full")
    this.drawerTarget.classList.remove("translate-x-0")
    this.backdropTarget.classList.add("hidden")
  }
}
```

- [ ] **Step 2: Replace question show view**

Replace `app/views/student/questions/show.html.erb` with:

```erb
<div data-controller="sidebar chat"
     data-chat-create-url-value="<%= student_conversations_path(access_code: params[:access_code]) %>"
     data-chat-message-url-value=""
     data-chat-question-id-value="<%= @question.id %>"
     data-chat-has-api-key-value="<%= current_student.api_key.present? %>"
     data-chat-settings-url-value="<%= student_settings_path(access_code: params[:access_code]) %>"
     data-chat-conversation-id-value="<%= @conversation&.id %>"
     class="flex min-h-screen">

  <%# Backdrop (mobile) %>
  <div data-sidebar-target="backdrop"
       data-action="click->sidebar#close"
       class="hidden fixed inset-0 bg-black/50 z-40 lg:hidden">
  </div>

  <%# Sidebar / Drawer %>
  <aside data-sidebar-target="drawer"
         class="w-[260px] bg-slate-900 dark:bg-slate-900 border-r border-slate-800 dark:border-slate-800 flex-shrink-0 overflow-y-auto
                fixed top-0 left-0 bottom-0 z-50 -translate-x-full transition-transform duration-200 ease-in-out
                lg:relative lg:translate-x-0 lg:z-auto">
    <%= render "student/questions/sidebar",
        subject: @subject,
        current_part: @part,
        current_question: @question,
        parts: @parts,
        questions_in_part: @questions_in_part,
        session_record: @session_record,
        access_code: params[:access_code] %>
  </aside>

  <%# Main content %>
  <div class="flex-1 px-4 py-5 max-w-3xl mx-auto w-full">
    <%# Top bar %>
    <div class="flex items-center gap-3 mb-5">
      <button data-action="click->sidebar#open"
              class="lg:hidden w-9 h-9 flex items-center justify-center bg-slate-100 dark:bg-slate-800 rounded-lg text-slate-500 dark:text-slate-400 cursor-pointer"
              aria-label="Ouvrir le menu">
        ☰
      </button>
      <span class="text-xs text-slate-500 dark:text-slate-400 whitespace-nowrap">
        <%= @part.title %> — Q<%= @question.number %>
        (<%= @questions_in_part.index(@question).to_i + 1 %>/<%= @questions_in_part.size %>)
      </span>
      <%
        total = @questions_in_part.size
        answered = @questions_in_part.count { |q| @session_record.answered?(q.id) }
      %>
      <%= render(ProgressBarComponent.new(current: answered, total: total)) %>
      <%= render(ButtonComponent.new(pill: true, size: :sm, data: { action: "click->chat#open" })) { "Tutorat" } %>
    </div>

    <%# Question card %>
    <div class="bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg p-4 mb-4">
      <div class="flex justify-between items-center mb-2">
        <span class="text-indigo-600 dark:text-indigo-400 font-semibold text-sm">Question <%= @question.number %></span>
        <%= render(BadgeComponent.new(color: :indigo, label: "#{@question.points} pts")) %>
      </div>
      <p class="text-sm text-slate-800 dark:text-slate-200 leading-relaxed mb-2"><%= @question.label %></p>
      <% if @question.context_text.present? %>
        <div class="border-l-3 border-slate-300 dark:border-slate-600 bg-slate-50 dark:bg-slate-900 rounded-r-md px-3 py-2">
          <p class="text-xs text-slate-500 dark:text-slate-400 italic leading-relaxed"><%= @question.context_text %></p>
        </div>
      <% end %>
    </div>

    <%# Document refs %>
    <% if @question.question_documents.any? %>
      <div class="flex items-center gap-2 mb-4">
        <span class="text-xs text-slate-500 dark:text-slate-400">Voir :</span>
        <% @question.question_documents.each do |qd| %>
          <span class="bg-slate-100 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 text-slate-600 dark:text-slate-400 text-xs px-3 py-1 rounded-md cursor-pointer hover:bg-slate-200 dark:hover:bg-slate-700">
            <%= qd.technical_document.display_name %> ↗
          </span>
        <% end %>
      </div>
    <% end %>

    <%# Correction area %>
    <%= turbo_frame_tag "question_#{@question.id}_correction" do %>
      <% if @session_record.answered?(@question.id) %>
        <%= render "student/questions/correction",
            question: @question, subject: @subject, session_record: @session_record %>
      <% elsif @question.answer %>
        <div class="text-center mb-4">
          <%= button_to "Voir la correction",
              student_reveal_question_path(access_code: params[:access_code], subject_id: @subject.id, id: @question.id),
              method: :patch,
              data: { turbo_frame: "question_#{@question.id}_correction" },
              class: "inline-flex items-center px-7 py-2.5 bg-emerald-500 text-white font-semibold text-sm rounded-full hover:bg-emerald-600 cursor-pointer" %>
        </div>
      <% end %>
    <% end %>

    <%# Navigation %>
    <%
      idx = @questions_in_part.index(@question).to_i
      prev_q = idx > 0 ? @questions_in_part[idx - 1] : nil
      next_q = idx < @questions_in_part.size - 1 ? @questions_in_part[idx + 1] : nil
    %>
    <div class="flex justify-between items-center pt-4 border-t border-slate-200 dark:border-slate-800">
      <% if prev_q %>
        <%= link_to "← Q#{prev_q.number}",
            student_question_path(access_code: params[:access_code], subject_id: @subject.id, id: prev_q.id),
            class: "text-sm text-indigo-600 dark:text-indigo-400 hover:text-indigo-700 dark:hover:text-indigo-300" %>
      <% else %>
        <span></span>
      <% end %>

      <% if next_q %>
        <%= render(ButtonComponent.new(variant: :success, pill: true, size: :sm,
            href: student_question_path(access_code: params[:access_code], subject_id: @subject.id, id: next_q.id))) { "Question suivante →" } %>
      <% else %>
        <%= render(ButtonComponent.new(variant: :success, pill: true, size: :sm,
            href: student_root_path(access_code: params[:access_code]))) { "Retour aux sujets" } %>
      <% end %>
    </div>
  </div>

  <%# Chat drawer %>
  <%= render "student/questions/chat_drawer", conversation: @conversation %>
</div>
```

- [ ] **Step 3: Replace sidebar partial**

Replace `app/views/student/questions/_sidebar.html.erb` with:

```erb
<div class="p-4">
  <%# Mise en situation %>
  <details open>
    <summary class="text-[10px] uppercase tracking-wider text-slate-500 cursor-pointer mb-1">Mise en situation</summary>
    <p class="text-xs font-medium text-slate-300 dark:text-slate-300 mb-1"><%= subject.title %></p>
    <p class="text-xs text-slate-500 leading-relaxed mb-4"><%= subject.presentation_text %></p>
  </details>

  <hr class="border-slate-800 mb-4">

  <%# Objectif %>
  <p class="text-[10px] uppercase tracking-wider text-slate-500 mb-1">Objectif — Partie <%= current_part.number %></p>
  <p class="text-xs text-slate-400 leading-relaxed mb-4"><%= current_part.objective_text %></p>

  <hr class="border-slate-800 mb-4">

  <%# Questions list %>
  <p class="text-[10px] uppercase tracking-wider text-slate-500 mb-2"><%= current_part.title %></p>
  <div class="flex flex-col gap-0.5">
    <% questions_in_part.each do |q| %>
      <% answered = session_record.answered?(q.id) %>
      <% current = q == current_question %>
      <%= link_to student_question_path(access_code: access_code, subject_id: subject.id, id: q.id),
          class: "flex items-center gap-2 px-2 py-1.5 rounded-md text-xs no-underline transition-colors #{current ? 'bg-indigo-500/10 text-white font-medium' : 'text-slate-400 hover:bg-slate-800'}",
          data: { action: "click->sidebar#close" } do %>
        <span class="<%= answered ? 'text-emerald-400' : current ? 'text-indigo-400' : 'text-slate-600' %>">
          <%= answered ? "✓" : current ? "◉" : "○" %>
        </span>
        Q<%= q.number %> (<%= q.points %> pts)
      <% end %>
    <% end %>
  </div>

  <hr class="border-slate-800 my-4">

  <%# Autres parties %>
  <p class="text-[10px] uppercase tracking-wider text-slate-500 mb-2">Autres parties</p>
  <% parts.each do |p| %>
    <% next if p == current_part %>
    <% part_questions = p.questions.kept %>
    <% part_answered = part_questions.count { |q| session_record.answered?(q.id) } %>
    <%= link_to student_subject_path(access_code: access_code, id: subject.id, part_id: p.id),
        class: "block px-2 py-1.5 text-xs text-slate-300 no-underline hover:bg-slate-800 rounded-md" do %>
      <%= p.title %> (<%= part_answered %>/<%= part_questions.size %>)
    <% end %>
  <% end %>

  <hr class="border-slate-800 my-4">

  <%# Documents %>
  <p class="text-[10px] uppercase tracking-wider text-slate-500 mb-2">Documents</p>
  <% if subject.dt_file.attached? %>
    <%= link_to rails_blob_path(subject.dt_file, disposition: "inline"),
        target: "_blank",
        class: "flex items-center gap-2 py-1 text-xs text-blue-400 no-underline hover:text-blue-300" do %>
      <span class="bg-blue-500/10 text-blue-400 text-[9px] font-semibold px-1.5 py-0.5 rounded">DT</span>
      Documents Techniques ↗
    <% end %>
  <% end %>
  <% if subject.dr_vierge_file.attached? %>
    <%= link_to rails_blob_path(subject.dr_vierge_file, disposition: "attachment"),
        class: "flex items-center gap-2 py-1 text-xs text-amber-400 no-underline hover:text-amber-300" do %>
      <span class="bg-amber-500/10 text-amber-400 text-[9px] font-semibold px-1.5 py-0.5 rounded">DR</span>
      DR vierge ↗
    <% end %>
  <% end %>
  <% if session_record.answered?(current_question.id) %>
    <% if subject.dr_corrige_file.attached? %>
      <%= link_to rails_blob_path(subject.dr_corrige_file, disposition: "inline"),
          target: "_blank",
          class: "flex items-center gap-2 py-1 text-xs text-blue-400 no-underline hover:text-blue-300" do %>
        DR corrigé ↗
      <% end %>
    <% end %>
    <% if subject.questions_corrigees_file.attached? %>
      <%= link_to rails_blob_path(subject.questions_corrigees_file, disposition: "inline"),
          target: "_blank",
          class: "flex items-center gap-2 py-1 text-xs text-blue-400 no-underline hover:text-blue-300" do %>
        Questions corrigées ↗
      <% end %>
    <% end %>
  <% end %>

  <hr class="border-slate-800 my-4">

  <%= link_to "⚙ Réglages", student_settings_path(access_code: access_code),
      class: "block px-2 py-1.5 text-xs text-slate-400 no-underline hover:bg-slate-800 rounded-md" %>
</div>
```

- [ ] **Step 4: Replace correction partial**

Replace `app/views/student/questions/_correction.html.erb` with:

```erb
<div class="space-y-3 mb-4">
  <%# Correction %>
  <div class="border-l-3 border-emerald-500 bg-emerald-50 dark:bg-emerald-500/5 rounded-r-lg px-4 py-3">
    <p class="text-emerald-700 dark:text-emerald-400 font-semibold text-xs uppercase mb-2">✓ Correction</p>
    <p class="text-sm text-slate-800 dark:text-slate-200 leading-relaxed"><%= question.answer&.correction_text %></p>
  </div>

  <%# Explication %>
  <% if question.answer&.explanation_text.present? %>
    <div class="bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg px-4 py-3">
      <p class="text-blue-600 dark:text-blue-400 font-semibold text-xs mb-2">Explication</p>
      <p class="text-sm text-slate-600 dark:text-slate-300 leading-relaxed"><%= question.answer.explanation_text %></p>
    </div>
  <% end %>

  <%# Data hints %>
  <% if question.answer&.data_hints.present? %>
    <div class="bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg px-4 py-3">
      <p class="text-amber-600 dark:text-amber-400 font-semibold text-xs mb-2">Où trouver les données ?</p>
      <div class="space-y-1.5">
        <% question.answer.data_hints.each do |hint| %>
          <div class="flex items-center gap-2">
            <%= render(BadgeComponent.new(color: :amber, label: hint["source"])) %>
            <span class="text-xs text-slate-500 dark:text-slate-400"><%= hint["location"] %></span>
          </div>
        <% end %>
      </div>
    </div>
  <% end %>

  <%# Key concepts %>
  <% if question.answer&.key_concepts.present? %>
    <div class="bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg px-4 py-3">
      <p class="text-indigo-600 dark:text-indigo-400 font-semibold text-xs mb-2">Concepts clés</p>
      <div class="flex gap-1.5 flex-wrap">
        <% question.answer.key_concepts.each do |concept| %>
          <span class="bg-indigo-500/10 text-indigo-600 dark:text-indigo-300 text-xs px-2.5 py-1 rounded-full"><%= concept %></span>
        <% end %>
      </div>
    </div>
  <% end %>

  <%# Documents correction %>
  <% if subject.dr_corrige_file.attached? || subject.questions_corrigees_file.attached? %>
    <div class="bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg px-4 py-3">
      <p class="text-slate-500 dark:text-slate-400 font-semibold text-xs mb-2">Documents correction</p>
      <% if subject.dr_corrige_file.attached? %>
        <%= link_to "DR corrigé ↗", rails_blob_path(subject.dr_corrige_file, disposition: "inline"),
            target: "_blank", class: "block text-sm text-blue-600 dark:text-blue-400 no-underline hover:underline mb-1" %>
      <% end %>
      <% if subject.questions_corrigees_file.attached? %>
        <%= link_to "Questions corrigées ↗", rails_blob_path(subject.questions_corrigees_file, disposition: "inline"),
            target: "_blank", class: "block text-sm text-blue-600 dark:text-blue-400 no-underline hover:underline" %>
      <% end %>
    </div>
  <% end %>
</div>
```

- [ ] **Step 5: Run feature tests**

```bash
bin/rails tailwindcss:build && bundle exec rspec spec/features/ --fail-fast
```

Fix any test selectors. Common changes: inline `style=` selectors → Tailwind class selectors, button text matching stays the same.

- [ ] **Step 6: Commit**

```bash
git add app/views/student/questions/ app/javascript/controllers/sidebar_controller.js
git commit -m "feat(student): migrate question screen + sidebar + correction to Tailwind

Desktop sidebar, mobile drawer, question card, correction with data hints
and key concepts. Sidebar controller now uses CSS classes."
```

---

### Task 15: Migrate student settings + chat drawer

**Files:**
- Modify: `app/views/student/settings/show.html.erb`
- Modify: `app/views/student/questions/_chat_drawer.html.erb`
- Modify: `app/javascript/controllers/chat_controller.js`

- [ ] **Step 1: Replace settings page**

Replace `app/views/student/settings/show.html.erb` — follow the same pattern as other views. Replace all `style=` attributes with Tailwind classes. Use:
- `bg-white dark:bg-slate-800` for card backgrounds
- `border border-slate-200 dark:border-slate-700` for borders
- `text-slate-800 dark:text-slate-200` for primary text
- `text-slate-500 dark:text-slate-400` for secondary text
- Input fields: `w-full px-4 py-2.5 bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg text-sm`
- Radio cards: `border-2 border-slate-200 dark:border-slate-700 rounded-lg p-4 cursor-pointer` + `border-indigo-500` when selected
- Use `ButtonComponent` for submit and test buttons
- NavBar with back link to subjects

- [ ] **Step 2: Update chat drawer to use Tailwind classes**

Replace inline styles in `app/views/student/questions/_chat_drawer.html.erb` with Tailwind classes. The drawer structure:
- Backdrop: `hidden fixed inset-0 bg-black/50 z-50`
- Drawer panel: `fixed top-0 right-0 bottom-0 w-full lg:w-[400px] bg-white dark:bg-slate-900 border-l border-slate-200 dark:border-slate-700 z-50 translate-x-full transition-transform`
- Header: `flex items-center justify-between px-4 py-3 border-b border-slate-200 dark:border-slate-700`
- Messages area: `flex-1 overflow-y-auto px-4 py-3 space-y-3`
- AI bubble: `bg-slate-100 dark:bg-slate-800 rounded-lg px-3 py-2 text-sm`
- User bubble: `bg-indigo-50 dark:bg-indigo-500/10 rounded-lg px-3 py-2 text-sm ml-8`
- Input area: `border-t border-slate-200 dark:border-slate-700 px-4 py-3 flex gap-2`

- [ ] **Step 3: Update chat controller to use classes instead of inline styles**

In `app/javascript/controllers/chat_controller.js`, replace any `element.style.cssText` or `element.style.*` calls with `classList.add/remove/toggle` using Tailwind classes. Key changes:
- Drawer open: remove `translate-x-full`, add `translate-x-0`
- Backdrop show/hide: toggle `hidden` class
- Streaming indicator: use Tailwind class `animate-pulse`

- [ ] **Step 4: Run feature tests**

```bash
bin/rails tailwindcss:build && bundle exec rspec spec/features/ --fail-fast
```

- [ ] **Step 5: Commit**

```bash
git add app/views/student/settings/show.html.erb app/views/student/questions/_chat_drawer.html.erb app/javascript/controllers/chat_controller.js
git commit -m "feat(student): migrate settings page + chat drawer to Tailwind

Radio card selection, AI config form, chat drawer with Tailwind classes.
Chat controller uses classList instead of inline styles."
```

---

### Task 16: Migrate teacher classrooms views

**Files:**
- Modify: `app/views/teacher/classrooms/index.html.erb`
- Modify: `app/views/teacher/classrooms/show.html.erb`
- Modify: `app/views/teacher/classrooms/new.html.erb`

- [ ] **Step 1: Replace classrooms index**

Use `CardComponent` grid layout (same pattern as student dashboard). Each class card shows:
- Body: name (`text-sm font-semibold`), year + specialty badges, student count, subject count
- Footer: `link_to "Voir →"` styled as indigo text link

Top: `h1` "Mes classes" + `ButtonComponent` "Nouvelle classe" (indigo pill, `href: new_teacher_classroom_path`)

Grid: `grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4`

- [ ] **Step 2: Replace classrooms show**

- Header: classroom name + badges + access code in a `code` tag with copy-to-clipboard styling
- Students section: `<table>` with Tailwind classes: `w-full text-sm`, `<thead>` with `bg-slate-50 dark:bg-slate-800`, `<th>` with `px-4 py-2 text-left text-xs font-medium text-slate-500 uppercase`, `<td>` with `px-4 py-3 border-t border-slate-200 dark:border-slate-700`
- Action buttons above table: `ButtonComponent` "Ajouter un élève" (primary sm) + "Ajout en lot" (ghost sm) + "Exporter PDF" (ghost sm)
- Row actions: reset password + delete with ghost sm buttons

- [ ] **Step 3: Replace classrooms new**

Centered CardComponent form. Input fields with Tailwind classes. Submit with `ButtonComponent`.

- [ ] **Step 4: Run tests**

```bash
bin/rails tailwindcss:build && bundle exec rspec spec/features/ --fail-fast
```

- [ ] **Step 5: Commit**

```bash
git add app/views/teacher/classrooms/
git commit -m "feat(teacher): migrate classrooms views to Tailwind + components

Index grid with CardComponent, show with styled table, new form."
```

---

### Task 17: Migrate teacher subjects views

**Files:**
- Modify: `app/views/teacher/subjects/index.html.erb`
- Modify: `app/views/teacher/subjects/show.html.erb`
- Modify: `app/views/teacher/subjects/new.html.erb`
- Modify: `app/views/teacher/subjects/assign.html.erb`
- Modify: `app/views/teacher/subjects/_extraction_status.html.erb`
- Modify: `app/views/teacher/subjects/_stats.html.erb`

- [ ] **Step 1: Replace subjects index**

Table layout with:
- Header: "Mes sujets" + `ButtonComponent` "Nouveau sujet" (indigo pill)
- Table with Tailwind classes (same pattern as classrooms)
- Columns: titre, spécialité (BadgeComponent indigo), année (BadgeComponent emerald), statut (BadgeComponent — slate for draft, amber for pending, emerald for published), date, nb questions
- Row links to subject show

- [ ] **Step 2: Replace subjects show**

- Header: title + badges + action buttons (publish/unpublish/assign as ButtonComponent ghost)
- Files section: CardComponent listing attached PDFs with links
- Extraction status partial: use BadgeComponent for status + ButtonComponent for retry
- Stats partial: ProgressBarComponent for validation + publish/unpublish ButtonComponent
- Parts accordion: `<details>` tags with Tailwind styling, questions listed inside

- [ ] **Step 3: Replace subjects new + assign**

- New: centered CardComponent form with file upload inputs styled in Tailwind
- Assign: checkbox list with Tailwind form styling

- [ ] **Step 4: Run tests**

```bash
bin/rails tailwindcss:build && bundle exec rspec spec/features/ --fail-fast
```

- [ ] **Step 5: Commit**

```bash
git add app/views/teacher/subjects/
git commit -m "feat(teacher): migrate subjects views to Tailwind + components

Index table, show with extraction status and parts accordion,
new form with file uploads, assign checkboxes."
```

---

### Task 18: Migrate teacher parts + questions + students views

**Files:**
- Modify: `app/views/teacher/parts/show.html.erb`
- Modify: `app/views/teacher/questions/_question.html.erb`
- Modify: `app/views/teacher/questions/_question_form.html.erb`
- Modify: `app/views/teacher/students/new.html.erb`
- Modify: `app/views/teacher/students/bulk_new.html.erb`

- [ ] **Step 1: Replace parts show**

Two-column layout: left panel with questions list (using CardComponent and BadgeComponent for status), right panel with PDF iframe. Use `grid grid-cols-1 lg:grid-cols-2 gap-4`.

- [ ] **Step 2: Replace question partial + form**

- Question card: turbo_frame wrapper, CardComponent with question number, label (truncated), points badge, status badge, action buttons (validate/invalidate as ButtonComponent success/ghost, delete as ButtonComponent with `data-turbo-confirm`)
- Question form: inline form in CardComponent with textarea for label, number inputs for points, select for answer_type, textareas for correction/explanation

- [ ] **Step 3: Replace students new + bulk_new**

- New: simple centered CardComponent form (first_name, last_name, submit)
- Bulk new: CardComponent with textarea ("un élève par ligne") + submit

- [ ] **Step 4: Run all tests**

```bash
bin/rails tailwindcss:build && bundle exec rspec
```

Expected: All tests pass. This is the final migration step.

- [ ] **Step 5: Commit**

```bash
git add app/views/teacher/parts/ app/views/teacher/questions/ app/views/teacher/students/
git commit -m "feat(teacher): migrate parts, questions, and students views to Tailwind

Parts two-column layout, question cards with inline edit form,
student creation forms."
```

---

### Task 19: Final cleanup + remove inline styles

**Files:**
- All view files (verification pass)
- `app/assets/stylesheets/application.css`

- [ ] **Step 1: Search for remaining inline styles**

```bash
grep -rn "style=" app/views/ --include="*.erb" | head -30
```

Expected: No results (all inline styles should be migrated). If any remain, migrate them.

- [ ] **Step 2: Clean up application.css**

Verify `app/assets/stylesheets/application.css` is either empty (just the manifest comment) or only contains non-Tailwind global styles. Tailwind is in `app/assets/tailwind/application.css`.

- [ ] **Step 3: Run full test suite**

```bash
bin/rails tailwindcss:build && bundle exec rspec
```

Expected: All tests pass.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "chore(cleanup): remove remaining inline styles after Tailwind migration"
```

---

## Summary

| Task | Description | Files |
|------|-------------|-------|
| 1 | Install Tailwind CSS 4 | Gemfile, puma.rb, tailwind/application.css |
| 2 | Install ViewComponent | Gemfile, rails_helper.rb |
| 3 | ButtonComponent | 2 new files |
| 4 | BadgeComponent | 2 new files |
| 5 | CardComponent | 3 new files |
| 6 | ProgressBarComponent | 2 new files |
| 7 | ThemeToggle + Stimulus | 3 new files |
| 8 | NavBarComponent | 3 new files |
| 9 | Flash + Modal components | 5 new files |
| 10 | Update layouts | 2 modified |
| 11 | Home page | 1 modified |
| 12 | Student login | 1 modified |
| 13 | Student dashboard | 1 modified |
| 14 | Student question screen | 4 modified |
| 15 | Student settings + chat | 3 modified |
| 16 | Teacher classrooms | 3 modified |
| 17 | Teacher subjects | 6 modified |
| 18 | Teacher parts/questions/students | 5 modified |
| 19 | Final cleanup | verification pass |
