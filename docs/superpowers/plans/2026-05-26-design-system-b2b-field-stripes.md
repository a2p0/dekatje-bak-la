# Design System B2b — FieldComponent + StripesComponent Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create two new atomic ViewComponents (`FieldComponent` and `StripesComponent`) consuming real B1 semantic tokens, and mark the legacy `_field.html.erb` partial as DEPRECATED, with zero view migration.

**Architecture:** Both components are atomic (no consumers in this PR — adoption deferred to B5/B7). `FieldComponent` is a form-builder-aware wrapper supporting 6 input types (`:text, :textarea, :file, :file_dropzone, :select, :checkbox`) with label/hint/error built-in. `StripesComponent` is a 4-color Radical signature bar with zero params, audience-aware via accent tokens. Pattern follows B2a: B1 contract guard spec to prevent token drift.

**Tech Stack:** Ruby 3.3 / Rails 8.1.3, ViewComponent, Tailwind CSS v4 (tokens sémantiques B1), RSpec + Capybara `render_inline`.

**Spec source:** `docs/superpowers/specs/2026-05-26-design-system-b2b-field-stripes-design.md`

**DEPRECATED removal tracking:** [issue #109](https://github.com/a2p0/dekatje-bak-la/issues/109) — to be extended with a B2b section in Task 1.

---

## File Structure

### Created
- `app/components/stripes_component.rb` — atomic, `.call` style, zero params
- `app/components/field_component.rb` — atomic, form-builder-aware, 6 types
- `app/components/field_component.html.erb` — template branching on `@type`
- `spec/components/stripes_component_spec.rb` — 5 examples
- `spec/components/field_component_spec.rb` — ~14 examples

### Modified
- `app/views/teacher/shared/_field.html.erb` — header DEPRECATED comment only, no behavior change

### Out of scope (no change)
- The 4 teacher views consuming the partial — left intact (migration in B5).
- Layouts (`application.html.erb`, `teacher.html.erb`, `student.html.erb`) — not yet consuming Stripes.

---

## Task 0: Setup (worktree)

**Files:** none (git only)

- [ ] **Step 1: Verify we're on main and clean**

Run from `/home/fz/Documents/Dev/claudeCLI/DekatjeBakLa`:
```bash
git status
git log --oneline -3
```
Expected: branch `main`, latest commit is `7d00ab1 docs(b2b): design spec — FieldComponent + StripesComponent`.

- [ ] **Step 2: Create the isolated worktree**

```bash
git worktree add -b 067-design-system-b2b-field-stripes .claude/worktrees/067-b2b-field-stripes main
```
Expected: `Préparation de l'arbre de travail (nouvelle branche '067-design-system-b2b-field-stripes')`.

- [ ] **Step 3: Cd into the worktree and verify state**

```bash
cd .claude/worktrees/067-b2b-field-stripes
git branch --show-current
git log --oneline -3
```
Expected: branch `067-design-system-b2b-field-stripes`, HEAD points to the same commit as main.

All subsequent tasks run from this worktree.

---

## Task 1: Extend issue #109 with B2b section

**Files:** none (gh CLI only)

Issue #109 already exists (created during B2a). We append a B2b section so future cleanup tracks both batches.

- [ ] **Step 1: Fetch current issue body**

```bash
gh issue view 109 --json body --jq '.body' > /tmp/issue_109_current.md
cat /tmp/issue_109_current.md | head -20
```
Expected: the issue body printed (contains B2a sections for Button/Badge/Card).

- [ ] **Step 2: Append B2b section to the issue body**

Write the new body to a file (avoid heredoc-stdin per CLAUDE.md rules):

Create `/tmp/issue_109_b2b_append.md`:
```markdown

### B2b — Partial `_field.html.erb` à migrer

`app/views/teacher/shared/_field.html.erb` reste actif pour 4 vues teacher.
À migrer vers `FieldComponent` en B5 (reskin teacher) :
- app/views/teacher/classrooms/new.html.erb
- app/views/teacher/classrooms/edit.html.erb
- app/views/teacher/subjects/new.html.erb
- app/views/teacher/questions/_question_form.html.erb

Une fois les 4 vues migrées, supprimer le partial.
```

Then concatenate and update:
```bash
cat /tmp/issue_109_current.md /tmp/issue_109_b2b_append.md > /tmp/issue_109_new.md
gh issue edit 109 --body-file /tmp/issue_109_new.md
```
Expected: issue URL printed, no error.

- [ ] **Step 3: Verify update**

```bash
gh issue view 109 --json body --jq '.body' | grep -A 8 "B2b"
```
Expected: the new B2b section visible.

---

## Task 2: StripesComponent — TDD

**Files:**
- Create: `spec/components/stripes_component_spec.rb`
- Create: `app/components/stripes_component.rb`

Starting with Stripes because it's tiny — calibrates the `.call`-style pattern for the rest.

- [ ] **Step 1: Write the failing spec (RED)**

Create `spec/components/stripes_component_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe StripesComponent, type: :component do
  describe "rendering" do
    before { render_inline(described_class.new) }

    it "renders a wrapper div with flex, h-[5px], and flex-shrink-0" do
      expect(page).to have_css("div.flex.h-\\[5px\\].flex-shrink-0")
    end

    it "marks the wrapper as aria-hidden (decorative)" do
      expect(page).to have_css("div[aria-hidden='true']")
    end

    it "renders exactly 4 child stripes" do
      expect(page).to have_css("div.flex.h-\\[5px\\] > div", count: 4)
    end

    it "uses the 4 audience-aware tokens in order: accent-primary, warning, accent-secondary, on-surface" do
      html = page.native.to_html
      # Order matters — assert the 4 background classes appear in sequence
      idx_primary    = html.index("bg-accent-primary")
      idx_warning    = html.index("bg-warning")
      idx_secondary  = html.index("bg-accent-secondary")
      idx_on_surface = html.index("bg-on-surface")

      expect(idx_primary).not_to be_nil
      expect(idx_warning).not_to be_nil
      expect(idx_secondary).not_to be_nil
      expect(idx_on_surface).not_to be_nil

      expect(idx_primary).to be < idx_warning
      expect(idx_warning).to be < idx_secondary
      expect(idx_secondary).to be < idx_on_surface
    end
  end

  describe "B1 token contract — no dead spec tokens leak in" do
    UNDEFINED_TOKENS = %w[
      accent-warning accent-success accent-danger
      surface-elevated surface-inverse on-inverse
      text-text-primary text-text-muted border-text-primary
    ].freeze

    it "does not reference any undefined B1 token" do
      render_inline(described_class.new)
      html = page.native.to_html
      UNDEFINED_TOKENS.each do |bad|
        expect(html).not_to include(bad), "StripesComponent rendered undefined token '#{bad}' — see B1 contract"
      end
    end
  end
end
```

- [ ] **Step 2: Run the spec — verify it fails (RED)**

```bash
bundle exec rspec spec/components/stripes_component_spec.rb
```
Expected: 5 failures, all because `StripesComponent` is not defined.

- [ ] **Step 3: Create the component**

Create `app/components/stripes_component.rb`:

```ruby
class StripesComponent < ViewComponent::Base
  # Radical signature: 4 horizontal stripes, 5px tall, audience-aware via accent tokens.
  # Decorative only — aria-hidden="true". Zero params (signature is fixed).
  #
  # Color mapping (B1 semantic tokens):
  #   stripe 1 → accent-primary   (red on student, teal on teacher after audience swap)
  #   stripe 2 → warning          (yellow, global state token — identical across audiences)
  #   stripe 3 → accent-secondary (teal on student, red on teacher)
  #   stripe 4 → on-surface       (ink in light, cream in dark)
  def call
    content_tag(:div, class: "flex h-[5px] flex-shrink-0", "aria-hidden": "true") do
      safe_join([
        content_tag(:div, "", class: "flex-1 bg-accent-primary"),
        content_tag(:div, "", class: "flex-1 bg-warning"),
        content_tag(:div, "", class: "flex-1 bg-accent-secondary"),
        content_tag(:div, "", class: "flex-1 bg-on-surface")
      ])
    end
  end
end
```

- [ ] **Step 4: Run the spec — verify it passes (GREEN)**

```bash
bundle exec rspec spec/components/stripes_component_spec.rb
```
Expected: `5 examples, 0 failures`.

- [ ] **Step 5: Commit**

```bash
git add app/components/stripes_component.rb spec/components/stripes_component_spec.rb
git commit -m "feat(b2b): StripesComponent — 4-color Radical signature bar

Atomic ViewComponent rendering a horizontal 5px decorative bar with the
4 Radical colors mapped to B1 audience-aware tokens (accent-primary,
warning, accent-secondary, on-surface). Zero params (fixed signature).
aria-hidden=true (decorative).

5/5 specs pass, B1 token contract guard included."
```

---

## Task 3: FieldComponent — basic structure + :text type (TDD)

**Files:**
- Create: `spec/components/field_component_spec.rb`
- Create: `app/components/field_component.rb`
- Create: `app/components/field_component.html.erb`

Start with the simplest type to lock in the component skeleton, init signature, label/hint/error structure, then add other types incrementally.

- [ ] **Step 1: Write the failing spec for `:text` (RED)**

Create `spec/components/field_component_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe FieldComponent, type: :component do
  # Reusable form builder backed by a real ActiveModel-ish stub so error
  # presence can be controlled per spec.
  let(:model_class) do
    Class.new do
      include ActiveModel::Model
      include ActiveModel::Attributes
      attribute :name, :string
      attribute :bio, :string
      attribute :specialty, :string
      attribute :pdf
      attribute :accepted, :boolean
    end
  end

  let(:model) { model_class.new }
  let(:form) { ActionView::Helpers::FormBuilder.new("user", model, view_context_double, {}) }

  # Minimal view context. ViewComponent provides `vc_test_controller` in tests
  # but we need a form builder. Easiest: render the component and let it
  # receive a real builder through the controller's view context.
  def view_context_double
    controller.view_context
  end

  describe ":text type" do
    it "renders an <input type='text'> with B1 semantic classes" do
      render_inline(described_class.new(form: form, attribute: :name, label: "Nom"))
      expect(page).to have_css("input[type='text'][name='user[name]']")
      html = page.native.to_html
      expect(html).to include("bg-surface")
      expect(html).to include("text-on-surface")
      expect(html).to include("border-rule")
      expect(html).to include("rounded-lg")
      expect(html).to include("focus:ring-accent-secondary")
    end

    it "renders the label above the input with text-on-surface + font-semibold" do
      render_inline(described_class.new(form: form, attribute: :name, label: "Nom de la classe"))
      expect(page).to have_css("label.text-on-surface.font-semibold", text: "Nom de la classe")
    end

    it "renders the hint below the input when provided" do
      render_inline(described_class.new(form: form, attribute: :name, label: "Nom", hint: "Max 50 caractères"))
      expect(page).to have_css("p.text-on-surface-muted", text: "Max 50 caractères")
    end

    it "does not render a hint paragraph when hint is nil" do
      render_inline(described_class.new(form: form, attribute: :name, label: "Nom"))
      expect(page).not_to have_css("p.text-on-surface-muted")
    end

    it "renders error border + message when form.object has errors on the attribute" do
      model.errors.add(:name, "ne peut pas être vide")
      render_inline(described_class.new(form: form, attribute: :name, label: "Nom"))
      html = page.native.to_html
      expect(html).to include("border-danger")
      expect(page).to have_css("p.text-danger", text: "ne peut pas être vide")
    end
  end
end
```

- [ ] **Step 2: Run the spec — verify it fails (RED)**

```bash
bundle exec rspec spec/components/field_component_spec.rb
```
Expected: 5 failures (component not defined).

- [ ] **Step 3: Create the component (Ruby class)**

Create `app/components/field_component.rb`:

```ruby
class FieldComponent < ViewComponent::Base
  # Form-builder-aware input wrapper with label, hint, and error rendering.
  # Six supported types: :text, :textarea, :file, :file_dropzone, :select, :checkbox.
  # All inputs consume B1 semantic tokens (no hardcoded Tailwind color utilities).
  #
  # Adoption: zero consumers in B2b — see roadmap B5 for view migration away
  # from the DEPRECATED partial app/views/teacher/shared/_field.html.erb.

  SUPPORTED_TYPES = %i[text textarea file file_dropzone select checkbox].freeze

  # Tailwind classes applied to text/textarea/select/file/checkbox inputs.
  # :file_dropzone uses a different markup (label wrapper) so does not use this.
  BASE_INPUT_CLASSES = "w-full bg-surface text-on-surface border border-rule " \
                       "rounded-lg px-3 py-2 text-sm " \
                       "focus:outline-none focus:ring-2 focus:ring-accent-secondary " \
                       "focus:border-accent-primary " \
                       "disabled:opacity-60 disabled:cursor-not-allowed".freeze

  def initialize(form:, attribute:, label:, type: :text, hint: nil,
                 collection: nil, options: {})
    @form       = form
    @attribute  = attribute.to_sym
    @label      = label
    @type       = type.to_sym
    @hint       = hint
    @collection = collection
    @options    = options

    raise ArgumentError, "FieldComponent: unknown type :#{@type}" unless SUPPORTED_TYPES.include?(@type)
    raise ArgumentError, "FieldComponent: :select requires a collection" if @type == :select && @collection.nil?
  end

  def has_error?
    @form.object.respond_to?(:errors) && @form.object.errors[@attribute].any?
  end

  def error_messages
    return [] unless has_error?

    @form.object.errors[@attribute]
  end

  def input_classes
    extra = has_error? ? " border-danger" : ""
    BASE_INPUT_CLASSES + extra
  end

  # Merge user-supplied options with our class string. User classes win on conflict.
  def merged_options(extra_class: input_classes)
    user_class = @options[:class]
    merged_class = [extra_class, user_class].compact.join(" ")
    @options.merge(class: merged_class)
  end

  attr_reader :form, :attribute, :label, :type, :hint, :collection, :options
end
```

- [ ] **Step 4: Create the ERB template (only :text branch first)**

Create `app/components/field_component.html.erb`:

```erb
<div class="mb-4">
  <%= form.label attribute, label, class: "block text-sm font-semibold text-on-surface mb-1" %>

  <% case type %>
  <% when :text %>
    <%= form.text_field attribute, **merged_options %>
  <% end %>

  <% error_messages.each do |msg| %>
    <p class="text-danger text-xs mt-1 font-semibold"><%= msg %></p>
  <% end %>

  <% if hint && !has_error? %>
    <p class="text-on-surface-muted text-xs mt-1"><%= hint %></p>
  <% end %>
</div>
```

- [ ] **Step 5: Run the spec — verify it passes (GREEN)**

```bash
bundle exec rspec spec/components/field_component_spec.rb
```
Expected: `5 examples, 0 failures`.

If the form-builder construction in the spec raises (`undefined method 'view_context'` etc.), check the alternative spec approach: use `vc_test_controller.view_context` or wrap the render in a form. The above approach uses `controller.view_context` which ViewComponent provides during `render_inline`. If issues persist, replace `view_context_double` with a minimal manual builder:

```ruby
let(:form) do
  template = ActionView::Base.new(ActionView::LookupContext.new([]), {}, nil)
  ActionView::Helpers::FormBuilder.new("user", model, template, {})
end
```

- [ ] **Step 6: Commit**

```bash
git add app/components/field_component.rb app/components/field_component.html.erb spec/components/field_component_spec.rb
git commit -m "feat(b2b): FieldComponent — :text type with label/hint/error

Initial FieldComponent skeleton handling :text inputs with B1 semantic
tokens (bg-surface, border-rule, focus:ring-accent-secondary).
Renders label, optional hint, and error messages with border-danger
swap on the input when form.object.errors[attribute] is present.

Remaining types (:textarea, :file, :file_dropzone, :select, :checkbox)
follow in Tasks 4–8. 5/5 specs pass."
```

---

## Task 4: FieldComponent — :textarea type

**Files:**
- Modify: `spec/components/field_component_spec.rb`
- Modify: `app/components/field_component.html.erb`

- [ ] **Step 1: Write failing specs (RED)**

Append to `spec/components/field_component_spec.rb` (before the final `end`):

```ruby
  describe ":textarea type" do
    it "renders a <textarea> with B1 semantic classes" do
      render_inline(described_class.new(form: form, attribute: :bio, label: "Biographie", type: :textarea))
      expect(page).to have_css("textarea[name='user[bio]']")
      html = page.native.to_html
      expect(html).to include("bg-surface")
      expect(html).to include("border-rule")
    end

    it "forwards :rows from options to the textarea" do
      render_inline(described_class.new(
        form: form, attribute: :bio, label: "Bio", type: :textarea,
        options: { rows: 6 }
      ))
      expect(page).to have_css("textarea[rows='6']")
    end

    it "applies error border + message when form.object has errors" do
      model.errors.add(:bio, "trop long")
      render_inline(described_class.new(form: form, attribute: :bio, label: "Bio", type: :textarea))
      html = page.native.to_html
      expect(html).to include("border-danger")
      expect(page).to have_css("p.text-danger", text: "trop long")
    end
  end
```

- [ ] **Step 2: Run — verify the 3 new specs fail (RED)**

```bash
bundle exec rspec spec/components/field_component_spec.rb -e "textarea"
```
Expected: 3 failures (only `:text` branch handled in template).

- [ ] **Step 3: Add :textarea branch in the ERB**

Edit `app/components/field_component.html.erb`, in the `case type` block, replace the single `:text` branch with both:

```erb
  <% case type %>
  <% when :text %>
    <%= form.text_field attribute, **merged_options %>
  <% when :textarea %>
    <%= form.text_area attribute, **merged_options %>
  <% end %>
```

- [ ] **Step 4: Run — verify GREEN**

```bash
bundle exec rspec spec/components/field_component_spec.rb
```
Expected: 8 examples, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add app/components/field_component.html.erb spec/components/field_component_spec.rb
git commit -m "feat(b2b): FieldComponent — :textarea type"
```

---

## Task 5: FieldComponent — :select type with collection validation

**Files:**
- Modify: `spec/components/field_component_spec.rb`
- Modify: `app/components/field_component.html.erb`

- [ ] **Step 1: Write failing specs (RED)**

Append to `spec/components/field_component_spec.rb`:

```ruby
  describe ":select type" do
    let(:options_list) { [["SIN", "SIN"], ["ITEC", "ITEC"], ["EE", "EE"]] }

    it "renders a <select> with the collection options" do
      render_inline(described_class.new(
        form: form, attribute: :specialty, label: "Spécialité",
        type: :select, collection: options_list
      ))
      expect(page).to have_css("select[name='user[specialty]']")
      expect(page).to have_css("option[value='SIN']", text: "SIN")
      expect(page).to have_css("option[value='ITEC']", text: "ITEC")
      expect(page).to have_css("option[value='EE']", text: "EE")
    end

    it "applies B1 semantic classes on the select" do
      render_inline(described_class.new(
        form: form, attribute: :specialty, label: "Spé",
        type: :select, collection: options_list
      ))
      html = page.native.to_html
      expect(html).to include("bg-surface")
      expect(html).to include("border-rule")
    end

    it "raises ArgumentError when collection is missing" do
      expect {
        described_class.new(form: form, attribute: :specialty, label: "Spé", type: :select)
      }.to raise_error(ArgumentError, /collection/)
    end
  end
```

- [ ] **Step 2: Run — verify the 3 specs fail (RED)**

```bash
bundle exec rspec spec/components/field_component_spec.rb -e "select"
```
Expected: 3 failures (the ArgumentError already raises but the rendering specs fail because no `:select` branch in ERB).

Note: the `ArgumentError` spec actually already passes since the constructor validates. Confirm by running just that spec — if it passes, the count is 2 failures, not 3.

- [ ] **Step 3: Add :select branch in the ERB**

Edit `app/components/field_component.html.erb`, add to the `case type` block after `:textarea`:

```erb
  <% when :select %>
    <%= form.select attribute, collection, {}, **merged_options %>
```

The `form.select` signature is `(method, choices, options = {}, html_options = {})`. We pass `{}` for choices-options (no `prompt:` here — caller passes via `options:` if needed via the html_options slot — actually that's wrong, see step 4).

Wait — `form.select`'s options hash (3rd positional arg) holds things like `:prompt`, `:include_blank`, while the html_options (4th arg / kwargs) holds `:class`, `:id` etc. The `options:` we receive is a flat hash that may mix both. For simplicity in B2b, we route everything through html_options. Callers needing `:prompt` would pass it via `options:` and it would land as an HTML attribute (no-op). If that becomes a problem, B3/B5 can refactor. For now, document it.

- [ ] **Step 4: Update the :select branch to handle both option groups**

Actually the cleanest is: split known select-option keys from html-option keys in the component. Edit `app/components/field_component.rb` to add a helper:

```ruby
  SELECT_OPTION_KEYS = %i[prompt include_blank selected disabled].freeze

  def select_options
    @options.slice(*SELECT_OPTION_KEYS)
  end

  def select_html_options
    base = merged_options(extra_class: input_classes)
    base.except(*SELECT_OPTION_KEYS)
  end
```

And update the ERB to use these:

```erb
  <% when :select %>
    <%= form.select attribute, collection, select_options, **select_html_options %>
```

- [ ] **Step 5: Run — verify GREEN**

```bash
bundle exec rspec spec/components/field_component_spec.rb
```
Expected: 11 examples, 0 failures.

- [ ] **Step 6: Commit**

```bash
git add app/components/field_component.rb app/components/field_component.html.erb spec/components/field_component_spec.rb
git commit -m "feat(b2b): FieldComponent — :select type + collection validation

Splits :prompt/:include_blank from html_options when invoking
form.select so both can be passed through the unified options: hash.
Raises ArgumentError if collection missing."
```

---

## Task 6: FieldComponent — :file type (basic)

**Files:**
- Modify: `spec/components/field_component_spec.rb`
- Modify: `app/components/field_component.html.erb`

- [ ] **Step 1: Write failing specs (RED)**

Append to spec:

```ruby
  describe ":file type" do
    it "renders an <input type='file'> with file:-prefixed Tailwind classes for the button look" do
      render_inline(described_class.new(form: form, attribute: :pdf, label: "PDF", type: :file))
      expect(page).to have_css("input[type='file'][name='user[pdf]']")
      html = page.native.to_html
      expect(html).to include("file:bg-accent-secondary/15")
      expect(html).to include("file:text-accent-secondary")
    end

    it "forwards :accept from options" do
      render_inline(described_class.new(
        form: form, attribute: :pdf, label: "PDF", type: :file,
        options: { accept: "application/pdf" }
      ))
      expect(page).to have_css("input[accept='application/pdf']")
    end
  end
```

- [ ] **Step 2: Run — verify failure (RED)**

```bash
bundle exec rspec spec/components/field_component_spec.rb -e "file type"
```
Expected: 2 failures.

- [ ] **Step 3: Add :file branch in the ERB with file: classes**

Edit `app/components/field_component.html.erb`, add to the `case` block:

```erb
  <% when :file %>
    <%= form.file_field attribute, **merged_options(extra_class: file_input_classes) %>
```

And add the helper to `app/components/field_component.rb`:

```ruby
  FILE_INPUT_CLASSES = "w-full text-sm text-on-surface " \
                       "file:mr-4 file:py-2 file:px-4 file:rounded-lg file:border-0 " \
                       "file:text-sm file:font-semibold " \
                       "file:bg-accent-secondary/15 file:text-accent-secondary " \
                       "hover:file:bg-accent-secondary/25".freeze

  def file_input_classes
    extra = has_error? ? " border-danger" : ""
    FILE_INPUT_CLASSES + extra
  end
```

- [ ] **Step 4: Run — verify GREEN**

```bash
bundle exec rspec spec/components/field_component_spec.rb
```
Expected: 13 examples, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add app/components/field_component.rb app/components/field_component.html.erb spec/components/field_component_spec.rb
git commit -m "feat(b2b): FieldComponent — :file type with file:-prefixed Tailwind classes"
```

---

## Task 7: FieldComponent — :file_dropzone type with `<label>` wrapper

**Files:**
- Modify: `spec/components/field_component_spec.rb`
- Modify: `app/components/field_component.html.erb`

The dropzone uses a `<label>` HTML wrapper so clicking anywhere triggers the file input (no JS needed). The input is `sr-only`.

- [ ] **Step 1: Write failing specs (RED)**

Append to spec:

```ruby
  describe ":file_dropzone type" do
    it "renders a <label> wrapper with dashed border and the sr-only file input inside" do
      render_inline(described_class.new(form: form, attribute: :pdf, label: "PDF", type: :file_dropzone))
      # The <label> wrapper is the clickable area.
      expect(page).to have_css("label.border-dashed.border-rule.bg-surface-raised")
      # The actual file input is inside, marked sr-only.
      expect(page).to have_css("label input[type='file'].sr-only")
    end

    it "shows the fixed 'Déposer un fichier' text in accent-secondary" do
      render_inline(described_class.new(form: form, attribute: :pdf, label: "PDF", type: :file_dropzone))
      expect(page).to have_css("div.text-accent-secondary.font-semibold", text: "Déposer un fichier")
    end

    it "shows the hint as the secondary line when provided" do
      render_inline(described_class.new(
        form: form, attribute: :pdf, label: "PDF", type: :file_dropzone,
        hint: "PDF uniquement · max 20 Mo"
      ))
      expect(page).to have_css("div.text-on-surface-muted", text: "PDF uniquement · max 20 Mo")
    end

    it "embeds an SVG upload icon" do
      render_inline(described_class.new(form: form, attribute: :pdf, label: "PDF", type: :file_dropzone))
      expect(page).to have_css("label svg", visible: :all)
    end

    it "forwards :accept from options to the file input" do
      render_inline(described_class.new(
        form: form, attribute: :pdf, label: "PDF", type: :file_dropzone,
        options: { accept: "application/pdf" }
      ))
      expect(page).to have_css("label input[type='file'][accept='application/pdf']", visible: :all)
    end
  end
```

- [ ] **Step 2: Run — verify failure (RED)**

```bash
bundle exec rspec spec/components/field_component_spec.rb -e "file_dropzone"
```
Expected: 5 failures.

- [ ] **Step 3: Add :file_dropzone branch in the ERB**

The dropzone replaces the standard label-above-input pattern with a single clickable `<label>` containing everything. So we need to special-case it in the template.

Replace the entire ERB template with this updated version:

```erb
<div class="mb-4">
  <% if type == :file_dropzone %>
    <%# Dropzone uses <label> as the clickable wrapper. The visible label
        text ("Déposer un fichier") is fixed for design coherence. %>
    <%= form.label attribute, class: "w-full p-5 rounded-lg border-2 border-dashed border-rule bg-surface-raised flex flex-col items-center gap-2 cursor-pointer" do %>
      <div class="w-9 h-9 rounded-lg bg-accent-secondary/15 flex items-center justify-center">
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor"
             stroke-width="2" stroke-linecap="round" stroke-linejoin="round"
             class="text-accent-secondary">
          <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/>
          <polyline points="17 8 12 3 7 8"/>
          <line x1="12" y1="3" x2="12" y2="15"/>
        </svg>
      </div>
      <div class="text-center">
        <div class="text-sm font-semibold text-accent-secondary">Déposer un fichier</div>
        <% if hint %>
          <div class="text-xs text-on-surface-muted"><%= hint %></div>
        <% end %>
      </div>
      <%= form.file_field attribute, **options.merge(class: "sr-only") %>
    <% end %>
  <% else %>
    <%= form.label attribute, label, class: "block text-sm font-semibold text-on-surface mb-1" %>

    <% case type %>
    <% when :text %>
      <%= form.text_field attribute, **merged_options %>
    <% when :textarea %>
      <%= form.text_area attribute, **merged_options %>
    <% when :select %>
      <%= form.select attribute, collection, select_options, **select_html_options %>
    <% when :file %>
      <%= form.file_field attribute, **merged_options(extra_class: file_input_classes) %>
    <% end %>
  <% end %>

  <% error_messages.each do |msg| %>
    <p class="text-danger text-xs mt-1 font-semibold"><%= msg %></p>
  <% end %>

  <% if hint && type != :file_dropzone && !has_error? %>
    <p class="text-on-surface-muted text-xs mt-1"><%= hint %></p>
  <% end %>
</div>
```

(Note the hint paragraph at the bottom now excludes `:file_dropzone` — its hint is rendered inside the dropzone itself.)

- [ ] **Step 4: Run — verify GREEN**

```bash
bundle exec rspec spec/components/field_component_spec.rb
```
Expected: 18 examples, 0 failures.

If `have_css("label input...", visible: :all)` fails because `sr-only` is treated as hidden — that's why we pass `visible: :all`. If still failing, use raw HTML inspection:
```ruby
expect(page.native.to_html).to include('type="file"')
expect(page.native.to_html).to include('class="sr-only"')
```

- [ ] **Step 5: Commit**

```bash
git add app/components/field_component.html.erb spec/components/field_component_spec.rb
git commit -m "feat(b2b): FieldComponent — :file_dropzone with <label> wrapper

The dropzone is a <label> containing an sr-only <input type='file'>,
which makes the entire styled area clickable to open the file picker
via standard HTML semantics (no JavaScript needed). Hint is rendered
inside the dropzone instead of below."
```

---

## Task 8: FieldComponent — :checkbox type

**Files:**
- Modify: `spec/components/field_component_spec.rb`
- Modify: `app/components/field_component.html.erb`

Checkbox layout differs: label is inline next to the checkbox, not above.

- [ ] **Step 1: Write failing specs (RED)**

Append to spec:

```ruby
  describe ":checkbox type" do
    it "renders <input type='checkbox'> inside an inline <label>" do
      render_inline(described_class.new(form: form, attribute: :accepted, label: "J'accepte", type: :checkbox))
      expect(page).to have_css("label.flex.items-center input[type='checkbox'][name='user[accepted]']")
      expect(page).to have_css("label", text: "J'accepte")
    end

    it "applies accent-accent-primary on the checkbox" do
      render_inline(described_class.new(form: form, attribute: :accepted, label: "X", type: :checkbox))
      html = page.native.to_html
      expect(html).to include("accent-accent-primary")
    end

    it "shows the error message below when form.object has errors" do
      model.errors.add(:accepted, "obligatoire")
      render_inline(described_class.new(form: form, attribute: :accepted, label: "X", type: :checkbox))
      expect(page).to have_css("p.text-danger", text: "obligatoire")
    end
  end
```

- [ ] **Step 2: Run — verify failure (RED)**

```bash
bundle exec rspec spec/components/field_component_spec.rb -e "checkbox"
```
Expected: 3 failures.

- [ ] **Step 3: Add :checkbox special case in the ERB**

The checkbox needs to be a sibling of the inline label structure, not under the "label above input" pattern. Update the `<% else %>` branch in the ERB:

Replace the entire ERB template again with this updated version that adds the `:checkbox` branch:

```erb
<div class="mb-4">
  <% if type == :file_dropzone %>
    <%= form.label attribute, class: "w-full p-5 rounded-lg border-2 border-dashed border-rule bg-surface-raised flex flex-col items-center gap-2 cursor-pointer" do %>
      <div class="w-9 h-9 rounded-lg bg-accent-secondary/15 flex items-center justify-center">
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor"
             stroke-width="2" stroke-linecap="round" stroke-linejoin="round"
             class="text-accent-secondary">
          <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/>
          <polyline points="17 8 12 3 7 8"/>
          <line x1="12" y1="3" x2="12" y2="15"/>
        </svg>
      </div>
      <div class="text-center">
        <div class="text-sm font-semibold text-accent-secondary">Déposer un fichier</div>
        <% if hint %>
          <div class="text-xs text-on-surface-muted"><%= hint %></div>
        <% end %>
      </div>
      <%= form.file_field attribute, **options.merge(class: "sr-only") %>
    <% end %>
  <% elsif type == :checkbox %>
    <label class="flex items-center gap-2 text-sm font-medium text-on-surface cursor-pointer">
      <%= form.check_box attribute, **options.merge(class: "accent-accent-primary h-4 w-4 rounded #{options[:class]}".strip) %>
      <span><%= label %></span>
    </label>
  <% else %>
    <%= form.label attribute, label, class: "block text-sm font-semibold text-on-surface mb-1" %>

    <% case type %>
    <% when :text %>
      <%= form.text_field attribute, **merged_options %>
    <% when :textarea %>
      <%= form.text_area attribute, **merged_options %>
    <% when :select %>
      <%= form.select attribute, collection, select_options, **select_html_options %>
    <% when :file %>
      <%= form.file_field attribute, **merged_options(extra_class: file_input_classes) %>
    <% end %>
  <% end %>

  <% error_messages.each do |msg| %>
    <p class="text-danger text-xs mt-1 font-semibold"><%= msg %></p>
  <% end %>

  <% if hint && type != :file_dropzone && type != :checkbox && !has_error? %>
    <p class="text-on-surface-muted text-xs mt-1"><%= hint %></p>
  <% end %>
</div>
```

- [ ] **Step 4: Run — verify GREEN**

```bash
bundle exec rspec spec/components/field_component_spec.rb
```
Expected: 21 examples, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add app/components/field_component.html.erb spec/components/field_component_spec.rb
git commit -m "feat(b2b): FieldComponent — :checkbox with inline label layout

Checkbox layout uses an inline <label class='flex items-center'>
wrapping the input and a <span> for the label text, with
accent-accent-primary as the native checkbox color. Hint paragraph
is suppressed for checkbox (label is already inline)."
```

---

## Task 9: FieldComponent — options passthrough + B1 contract guard specs

**Files:**
- Modify: `spec/components/field_component_spec.rb`

Final coverage layer: confirm `options:` reaches the helper, and that no dead B1 tokens leak in.

- [ ] **Step 1: Write the additional specs**

Append to spec:

```ruby
  describe "options passthrough" do
    it "forwards :placeholder from options to a :text input" do
      render_inline(described_class.new(
        form: form, attribute: :name, label: "Nom", type: :text,
        options: { placeholder: "Ex: Terminale SIN" }
      ))
      expect(page).to have_css("input[placeholder='Ex: Terminale SIN']")
    end

    it "forwards :required from options" do
      render_inline(described_class.new(
        form: form, attribute: :name, label: "Nom", type: :text,
        options: { required: true }
      ))
      expect(page).to have_css("input[required]")
    end
  end

  describe "init validation" do
    it "raises ArgumentError for an unknown type" do
      expect {
        described_class.new(form: form, attribute: :name, label: "X", type: :unsupported)
      }.to raise_error(ArgumentError, /unknown type/)
    end
  end

  describe "B1 token contract — no dead spec tokens leak in" do
    UNDEFINED_TOKENS = %w[
      accent-warning accent-success accent-danger
      surface-elevated surface-inverse on-inverse
      text-text-primary text-text-muted border-text-primary
    ].freeze

    %i[text textarea file file_dropzone checkbox].each do |type|
      it "type :#{type} does not reference undefined B1 tokens" do
        render_inline(described_class.new(form: form, attribute: :name, label: "X", type: type))
        html = page.native.to_html
        UNDEFINED_TOKENS.each do |bad|
          expect(html).not_to include(bad), "FieldComponent type=#{type} rendered undefined token '#{bad}'"
        end
      end
    end

    it "type :select does not reference undefined B1 tokens" do
      render_inline(described_class.new(
        form: form, attribute: :specialty, label: "X", type: :select,
        collection: [["A", "a"]]
      ))
      html = page.native.to_html
      UNDEFINED_TOKENS.each do |bad|
        expect(html).not_to include(bad), "FieldComponent type=select rendered undefined token '#{bad}'"
      end
    end
  end
```

- [ ] **Step 2: Run — verify GREEN (no impl change needed; these are coverage)**

```bash
bundle exec rspec spec/components/field_component_spec.rb
```
Expected: 30 examples, 0 failures.

If any B1 contract spec fails (a dead token *did* leak in), do NOT silently fix — investigate and surface the issue.

- [ ] **Step 3: Commit**

```bash
git add spec/components/field_component_spec.rb
git commit -m "test(b2b): FieldComponent — options passthrough + B1 token contract guard

Locks in the design contract that no spec-fantasy tokens
(accent-warning, surface-elevated, etc.) ever leak into rendered HTML
for any of the 6 supported types. Same pattern as B2a."
```

---

## Task 10: DEPRECATED header on legacy `_field.html.erb` partial

**Files:**
- Modify: `app/views/teacher/shared/_field.html.erb`

- [ ] **Step 1: Read the current header**

```bash
sed -n '1,15p' app/views/teacher/shared/_field.html.erb
```
Expected output shows the existing 12-line locals doc.

- [ ] **Step 2: Replace the header**

Use Edit tool (not sed) to swap the leading `<%#  ...  %>` block. The current header starts at line 1 and ends at the line `%>` before `<% type ||= :text; ...`.

Replace the entire header comment with:

```erb
<%#
  DEPRECATED — see #109

  This partial is kept until B5 (teacher reskin) migrates the 4 calling views
  to FieldComponent:
    - app/views/teacher/classrooms/new.html.erb
    - app/views/teacher/classrooms/edit.html.erb
    - app/views/teacher/subjects/new.html.erb
    - app/views/teacher/questions/_question_form.html.erb

  New code should use FieldComponent:
    <%%= render FieldComponent.new(form: f, attribute: :name, label: "Nom", type: :text) %%>

  Tracked: https://github.com/a2p0/dekatje-bak-la/issues/109

  ## Original locals (preserved, no behavior change in B2b)
  f          — form builder Rails (obligatoire)
  field      — Symbol, nom du champ (obligatoire)
  label_text — String, texte du label (obligatoire)
  type       — Symbol : :text, :textarea, :file, :select, :checkbox (défaut :text)
  options    — Hash, options supplémentaires (défaut {})
  hint       — String optionnel
  collection — Array [label, value] pour :select
%>
```

The rest of the partial (the actual ERB rendering) stays **byte-identical**.

- [ ] **Step 3: Confirm no behavior change**

```bash
git diff app/views/teacher/shared/_field.html.erb
```
Expected: only the header comment changed. Rendering code lines (`<%= form.label %>`, the `case type` block, error/hint paragraphs) are unchanged.

- [ ] **Step 4: Run the existing teacher view specs to confirm no regression**

```bash
bundle exec rspec spec/requests/teacher/ spec/features/teacher_question_validation_spec.rb 2>&1 | tail -5
```
Expected: all previously-passing specs still pass.

- [ ] **Step 5: Commit**

```bash
git add app/views/teacher/shared/_field.html.erb
git commit -m "docs(b2b): mark teacher _field partial as DEPRECATED (see #109)

Header comment only — no behavior change. The 4 teacher views consuming
this partial continue to work identically. Migration to FieldComponent
happens in B5 (teacher reskin)."
```

---

## Task 11: Full sanity check

**Files:** none

- [ ] **Step 1: Full component spec suite**

```bash
bundle exec rspec spec/components/
```
Expected: all green. Component spec count before B2b = 111 (from B2a), so after B2b expect ~146 examples.

- [ ] **Step 2: Grep — no hardcoded indigo/emerald/violet/slate in new components**

```bash
grep -nE "bg-(indigo|emerald|violet|slate)-[0-9]" app/components/field_component.rb app/components/field_component.html.erb app/components/stripes_component.rb
```
Expected: 0 matches.

- [ ] **Step 3: Grep — DEPRECATED references**

```bash
grep -n "DEPRECATED" app/views/teacher/shared/_field.html.erb
grep -n "#109" app/views/teacher/shared/_field.html.erb
```
Expected: at least one match in each grep.

- [ ] **Step 4: Verify the 4 calling views still resolve the partial**

```bash
grep -rn "render \"teacher/shared/field\"" app/views | wc -l
```
Expected: ≥ 4 (number of call sites — unchanged from before B2b).

---

## Task 12: Push + open PR

**Files:** none (git/gh only)

- [ ] **Step 1: Push the branch**

```bash
git push -u origin 067-design-system-b2b-field-stripes
```
Expected: branch published, link to PR creation URL printed.

- [ ] **Step 2: Create the PR**

```bash
gh pr create \
  --title "feat(b2b): FieldComponent + StripesComponent (création atomes B2b)" \
  --body "$(cat <<'EOF'
## Summary

Phase 3/8 du chantier design system Radical unifié (suite B1 PR #102, B2a PR #110).

- **`FieldComponent`** : wrapper input form-builder-aware unifié, 6 types (`:text, :textarea, :file, :file_dropzone, :select, :checkbox`), tokens B1, label/hint/error built-in.
- **`StripesComponent`** : bandeau 4 couleurs Radical signature (5px), audience-aware via tokens accent, zéro paramètre.
- **`_field.html.erb`** partial existant marqué DEPRECATED (`see #109`) — comportement inchangé, migration des 4 vues teacher prévue en B5.

## YAGNI cuts explicites

- ❌ Types `:number, :email, :password` (aucun usage actuel)
- ❌ `label:` auto-derivation (requis)
- ❌ `accept:` séparé de `options:`
- ❌ Stripes configurable (hauteur, couleurs, orientation)
- ❌ Stimulus controller `dropzone` (drag-and-drop reporté à B5)

## Test plan

- [x] Specs ViewComponent verts (FieldComponent ~30 examples × 6 types + Stripes 5 examples)
- [x] B1 token contract guards (`UNDEFINED_TOKENS`) sur les deux composants — empêchent les dead tokens du spec original de revenir
- [x] Validation init : `:select` sans collection raise `ArgumentError`, type inconnu raise aussi
- [x] Aucune couleur Tailwind hardcoded dans les nouveaux composants (grep verified)
- [x] Partial `_field.html.erb` annoté DEPRECATED sans modification comportementale
- [x] 4 sites d'appel teacher inchangés
- [x] CI verte

## Références

- Spec : `docs/superpowers/specs/2026-05-26-design-system-b2b-field-stripes-design.md`
- Plan : `docs/superpowers/plans/2026-05-26-design-system-b2b-field-stripes.md`
- Issue de suivi DEPRECATED : #109 (étendue avec section B2b)
- Prérequis : PR #102 (B1 tokens), PR #110 (B2a refonte atomes)

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```
Expected: PR URL printed.

- [ ] **Step 3: Watch CI**

```bash
gh pr checks --watch
```
Expected: lint/scan_js/scan_ruby pass quickly; test job runs ~4-10 minutes.

If `student_tutor_chat_spec.rb` or `student_desktop_tutor_spec.rb` fail → that's the pre-existing issue #96 (drawer flake), not caused by B2b. Re-run with `gh run rerun <run-id> --failed`. If still flaking, admin-bypass-merge (pattern from B2a).

- [ ] **Step 4: Write project memory entry**

After merge, add a memory entry following the B2a precedent:

Create `~/.claude/projects/-home-fz-Documents-Dev-claudeCLI-DekatjeBakLa/memory/project_b2b_field_stripes_merged.md` with frontmatter, summary of what was shipped, commit SHA, decisions taken. Update `MEMORY.md` index.

---

## Self-Review

**Spec coverage check:**

| Spec section | Implemented by |
|---|---|
| §3.1 In scope — FieldComponent 6 types | Tasks 3-8 |
| §3.1 In scope — StripesComponent | Task 2 |
| §3.1 In scope — RSpec ViewComponent + B1 contract guards | Tasks 2, 3-9 |
| §3.1 In scope — DEPRECATED header on legacy partial | Task 10 |
| §3.1 In scope — Issue #109 extended | Task 1 |
| §4 SC-1 (tokens utilisés) | Tasks 2, 9 (grep + B1 guard) |
| §4 SC-2 (zero regression on 4 views) | Task 10 (header-only diff) + Task 11 (grep call-sites) |
| §4 SC-3 (6 types RSpec) | Tasks 3-8 |
| §4 SC-4 (Stripes structure RSpec) | Task 2 |
| §4 SC-5 (CI green) | Task 12 |
| §4 SC-6 (Issue #109 updated) | Task 1 |
| §5.1 FieldComponent API + validation | Tasks 3 (init + :text), 5 (`:select` raise), 9 (unknown type raise) |
| §5.2 StripesComponent API + a11y | Task 2 |
| §5.3 Partial DEPRECATED comment | Task 10 |
| §5.4 Ordre interne Stripes → Field → DEPRECATED | Tasks 2 → 3-9 → 10 ✓ |
| §6.1 Tests inventory | Tasks 2 (5 specs), 3-9 (~30 specs cumulés) |
| §6.2 CI inchangé | Task 12 |
| §6.3 Pas de visual regression | n/a — pattern B2a |
| §7 Mise à jour issue #109 | Task 1 |

**Placeholder scan:** Plan has no TBD/TODO/"appropriate error handling"/"similar to Task N". One forward-pointing note in Task 5 step 3 ("see step 4") is resolved in the next step. Acceptable.

**Type consistency:**
- `FieldComponent#initialize(form:, attribute:, label:, type:, hint:, collection:, options:)` — consistent across Tasks 3-9.
- `SUPPORTED_TYPES`, `BASE_INPUT_CLASSES`, `FILE_INPUT_CLASSES`, `SELECT_OPTION_KEYS` constants introduced in order Tasks 3, 6, 5 (note: `SELECT_OPTION_KEYS` introduced in Task 5 alongside its use). OK.
- `merged_options(extra_class:)`, `has_error?`, `error_messages`, `input_classes`, `file_input_classes`, `select_options`, `select_html_options` — all defined where first used. OK.
- ERB structure progressively replaced (full file overwrite in Tasks 7 and 8). The Task 8 full file is the final shape. OK.
