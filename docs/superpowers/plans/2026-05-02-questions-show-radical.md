# questions/show — Radical Reskin Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reskin `student/questions/show.html.erb` and `_correction.html.erb` to the Radical design system (cream palette, Fraunces serif, rad-* tokens).

**Architecture:** Pure CSS reskin + minimal HTML additions (stripes, accent bars, avatar T, segmented progress bar). No new Stimulus controllers, no Rails controller changes, no migrations. The Turbo Frame correction structure and all Stimulus data attributes are preserved exactly. Sidebar gets CSS-only reskin. `_correction_button.html.erb` gets button style update.

**Tech Stack:** Rails 8 ERB, Tailwind CSS 4 with rad-* tokens (`bg-rad-bg`, `text-rad-text`, `font-serif`, `font-mono`, `pattern-madras`), existing `_stripes` partial at `app/views/student/subjects/_stripes.html.erb`.

---

## File Map

| Action | File |
|---|---|
| Modify | `app/views/student/questions/show.html.erb` |
| Modify | `app/views/student/questions/_correction.html.erb` |
| Modify | `app/views/student/questions/_correction_button.html.erb` |
| Modify (CSS only) | `app/views/student/questions/_sidebar.html.erb` |
| Modify (CSS only) | `app/views/student/questions/_sidebar_part.html.erb` |
| Modify (specs) | `spec/requests/student/questions_spec.rb` |
| Modify (specs) | `spec/features/student/subject_workflow_spec.rb` |

---

## Context for all tasks

**Radical palette tokens** (defined in `app/assets/tailwind/application.css`):
- `bg-rad-bg` = cream `#fbf7ee`
- `bg-rad-paper` = white `#ffffff`
- `bg-rad-raise` = `#fdfaf3`
- `text-rad-text` = ink `#0e1b1f`
- `text-rad-muted` = `#6b665a`
- `border-rad-rule` = `#e6dcc1`
- `bg-rad-red` = `#d4452e`, `text-rad-red`
- `bg-rad-yellow` = `#e8b53f`, `text-rad-yellow`
- `bg-rad-teal` = `#127566`, `text-rad-teal`
- `bg-rad-green` = `#2e8b3a`, `text-rad-green`
- `bg-rad-ink` = `#0e1b1f`, `text-rad-ink`
- `text-rad-cream` = `#fbf7ee`
- `font-serif` = Fraunces
- `font-mono` = JetBrains Mono
- `pattern-madras` = utility class for the grid background

**Stripes partial**: `app/views/student/subjects/_stripes.html.erb` — renders a 6px (h-1.5) 4-color bar (red/yellow/teal/ink). Reused as-is.

**Invariants** (must not change):
- `turbo_frame_tag "question_#{@question.id}_correction"` — ID and structure
- `data-controller="sidebar chat-drawer"` on wrapper div
- `data-controller="tutor-activator"` + `data-action="click->tutor-activator#activate"` on Tibo button
- `data-chat-drawer-toggle="true"` on Tibo buttons
- `student_subject_part_completion_path` in `button_to` (end-of-part)
- All navigation paths: `prev_href`, `next_href`, `end_of_part_label`
- `data-action="click->sidebar#open"` on hamburger

---

### Task 1: Reskin show.html.erb — wrapper, stripes, sidebar aside

**Files:**
- Modify: `app/views/student/questions/show.html.erb` (lines 29–55)

- [ ] **Step 1: Write failing request spec**

In `spec/requests/student/questions_spec.rb`, add inside the existing `describe "GET /subjects/:subject_id/questions/:id (show)"` block:

```ruby
it "uses Radical cream background" do
  get student_question_path(access_code: classroom.access_code, subject_id: subject_obj.id, id: question.id)
  expect(response.body).to include("bg-rad-bg")
end

it "renders stripes" do
  get student_question_path(access_code: classroom.access_code, subject_id: subject_obj.id, id: question.id)
  expect(response.body).to include("bg-rad-red")
  expect(response.body).to include("bg-rad-yellow")
end
```

- [ ] **Step 2: Run specs to verify they fail**

```bash
bundle exec rspec spec/requests/student/questions_spec.rb -e "Radical cream" -e "renders stripes" --format documentation
```

Expected: 2 failures.

- [ ] **Step 3: Update show.html.erb — wrapper + stripes + sidebar**

Replace lines 29–55 of `app/views/student/questions/show.html.erb`:

```erb
<%= render "student/subjects/stripes" %>

<div data-controller="sidebar chat-drawer"
     class="flex min-h-[calc(100vh-57px)] pb-20 lg:pb-0 bg-rad-bg">

  <%# Backdrop (mobile only) %>
  <div data-sidebar-target="backdrop"
       data-action="click->sidebar#close"
       class="hidden fixed inset-0 bg-black/50 z-[var(--z-backdrop)] lg:hidden">
  </div>

  <%# Sidebar / Drawer — Radical light %>
  <aside id="sidebar-drawer"
         data-sidebar-target="drawer"
         data-controller="focus-trap"
         data-action="focus-trap:close->sidebar#close"
         aria-label="Navigation du sujet"
         class="w-[260px] bg-rad-paper border-r border-rad-rule flex-shrink-0 overflow-y-auto
                fixed top-0 left-0 bottom-0 z-[var(--z-sidebar)] -translate-x-full transition-transform duration-200
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
```

- [ ] **Step 4: Run specs to verify they pass**

```bash
bundle exec rspec spec/requests/student/questions_spec.rb -e "Radical cream" -e "renders stripes" --format documentation
```

Expected: 2 passing.

- [ ] **Step 5: Commit**

```bash
git add app/views/student/questions/show.html.erb spec/requests/student/questions_spec.rb
git commit -m "style(questions): Radical wrapper, stripes, sidebar aside"
```

---

### Task 2: Reskin show.html.erb — header compact (replaces breadcrumb + progress row)

**Files:**
- Modify: `app/views/student/questions/show.html.erb` (lines 57–106, breadcrumb + progress row)

- [ ] **Step 1: Write failing spec**

In `spec/requests/student/questions_spec.rb`, add:

```ruby
it "shows compact header with subject title" do
  get student_question_path(access_code: classroom.access_code, subject_id: subject_obj.id, id: question.id)
  expect(response.body).to include(subject_obj.title)
  expect(response.body).to include("tracking-[0.16em]")
end
```

- [ ] **Step 2: Run spec to verify it fails**

```bash
bundle exec rspec spec/requests/student/questions_spec.rb -e "compact header" --format documentation
```

Expected: 1 failure.

- [ ] **Step 3: Replace breadcrumb + progress row in show.html.erb**

Replace the entire main content `<div class="flex-1 ...">` opening section (lines 57–106, from `<%# Main content %>` through the closing `</div>` of the progress bar row) with:

```erb
  <%# Main content %>
  <div class="flex-1 px-4 py-5 max-w-3xl mx-auto w-full">

    <%# Compact header: ← | exam label + subject title | ≡ %>
    <div class="flex items-center justify-between mb-3">
      <%= link_to student_subject_path(access_code: params[:access_code], id: @subject.id),
          class: "text-rad-text text-xl leading-none no-underline flex-shrink-0 px-1" do %>
        ‹
      <% end %>
      <div class="text-center flex-1 min-w-0 px-3">
        <div class="text-[10.5px] tracking-[0.16em] uppercase text-rad-muted font-bold leading-none mb-1">
          <%= [@subject.exam_type&.upcase, @subject.specialty_label].compact.join(" · ") %>
        </div>
        <span class="font-serif italic text-[14px] text-rad-text leading-none block truncate"><%= @subject.title %></span>
      </div>
      <button data-action="click->sidebar#open"
              data-sidebar-target="toggle"
              aria-label="Ouvrir le menu"
              aria-expanded="false"
              aria-controls="sidebar-drawer"
              class="lg:hidden flex-shrink-0 w-9 h-9 flex items-center justify-center bg-transparent border-0 text-rad-text text-xl cursor-pointer">
        ≡
      </button>
      <div class="hidden lg:block w-9"></div><%# spacer for centering %>
    </div>

    <%# Segmented progress bar %>
    <div class="flex items-center gap-2.5 mb-4">
      <div class="flex flex-1 gap-[3px]">
        <% total.times do |i| %>
          <div class="flex-1 h-1 rounded-sm <%= i < answered ? 'bg-rad-teal' : i == answered ? 'bg-rad-red' : 'bg-rad-rule' %>"></div>
        <% end %>
      </div>
      <span class="text-[11px] text-rad-muted font-semibold whitespace-nowrap"><%= idx + 1 %> / <%= total %></span>
      <%# Tibo button — desktop %>
      <% if @tutor_available %>
        <button type="button"
                data-controller="tutor-activator"
                data-tutor-activator-subject-id-value="<%= @subject.id %>"
                data-tutor-activator-question-id-value="<%= @question.id %>"
                data-tutor-activator-conversations-url-value="<%= student_conversations_path(access_code: params[:access_code]) %>"
                data-action="click->tutor-activator#activate"
                data-chat-drawer-toggle="true"
                aria-label="Ouvrir le tutorat IA"
                aria-expanded="false"
                aria-controls="tutor-chat-drawer"
                class="hidden lg:inline-flex items-center gap-2 pl-2 pr-4 py-1.5 bg-rad-ink text-rad-cream border-0 rounded-full text-sm font-semibold cursor-pointer whitespace-nowrap shadow-[0_8px_20px_-8px_rgba(0,0,0,0.35)] transition-opacity hover:opacity-80">
          <span class="w-6 h-6 rounded-full bg-rad-red text-rad-cream flex items-center justify-center font-serif italic text-[13px] flex-shrink-0">T</span>
          Tibo
        </button>
      <% else %>
        <%= link_to "Activer le tuteur",
            student_settings_path(access_code: params[:access_code]),
            class: "hidden lg:inline-flex items-center gap-2 px-3 py-1.5 bg-rad-paper text-rad-muted border border-rad-rule rounded-full text-xs font-medium whitespace-nowrap hover:bg-rad-raise transition-colors no-underline" %>
      <% end %>
    </div>
```

Note: `@subject.specialty_label` — check if this method exists. If not, use `@subject.specialty&.humanize` or `@subject.specialty`. Verify with:
```bash
grep -r "specialty_label\|def specialty" app/models/subject.rb
```

- [ ] **Step 4: Run spec to verify it passes**

```bash
bundle exec rspec spec/requests/student/questions_spec.rb -e "compact header" --format documentation
```

Expected: 1 passing.

- [ ] **Step 5: Also run tutor button specs to ensure they still pass**

```bash
bundle exec rspec spec/requests/student/questions_spec.rb -e "tutor button" --format documentation
```

Expected: all passing. If `"💬 Tutorat"` checks fail, update them to `"Tibo"`.

- [ ] **Step 6: Commit**

```bash
git add app/views/student/questions/show.html.erb spec/requests/student/questions_spec.rb
git commit -m "style(questions): Radical compact header + segmented progress bar"
```

---

### Task 3: Reskin show.html.erb — part header, context card, question card

**Files:**
- Modify: `app/views/student/questions/show.html.erb` (lines 108–134)

- [ ] **Step 1: Write failing spec**

In `spec/requests/student/questions_spec.rb`, add:

```ruby
it "renders question label in serif card" do
  get student_question_path(access_code: classroom.access_code, subject_id: subject_obj.id, id: question.id)
  expect(response.body).to include("font-serif")
  expect(response.body).to include("bg-rad-red")
  expect(response.body).to include("bg-rad-paper")
end
```

- [ ] **Step 2: Run spec to verify it fails**

```bash
bundle exec rspec spec/requests/student/questions_spec.rb -e "serif card" --format documentation
```

Expected: 1 failure.

- [ ] **Step 3: Replace part header + context card + question card**

Replace lines 108–134 in `show.html.erb`:

```erb
    <%# Sticky part header %>
    <div class="sticky top-0 z-10 bg-rad-bg/95 backdrop-blur-sm -mx-4 px-4 py-2 mb-4 border-b border-rad-rule">
      <div class="text-[10.5px] tracking-[0.14em] uppercase text-rad-muted font-bold leading-none mb-1">
        Partie <%= @part.number %>
        <% if @part.section_type.present? %>
          · <%= @part.section_type == "specific" ? "Spécifique" : "Commune" %>
        <% end %>
      </div>
      <p class="font-serif text-[18px] text-rad-text leading-[1.3] m-0"><%= @part.title %></p>
    </div>

    <%# Context card (mise en situation locale) %>
    <% if @question.context_text.present? %>
      <div class="bg-rad-paper border border-rad-rule rounded-2xl p-4 mb-3">
        <div class="flex items-center gap-2 mb-2">
          <span class="w-1 h-[14px] bg-rad-yellow rounded-sm flex-shrink-0"></span>
          <span class="text-[10.5px] tracking-[0.14em] uppercase text-rad-muted font-bold">Mise en situation</span>
        </div>
        <p class="text-rad-muted text-[13px] leading-[1.55] m-0"><%= @question.context_text %></p>
      </div>
    <% end %>

    <%# Question card %>
    <div class="bg-rad-paper border border-rad-rule rounded-2xl p-4 mb-4 shadow-sm">
      <div class="flex items-start gap-3 mb-3">
        <%# Number box + DT/DR badges column %>
        <div class="flex-shrink-0 flex flex-col items-center gap-2">
          <div class="w-14 h-14 rounded-[14px] bg-rad-red flex items-center justify-center">
            <span class="font-serif text-[22px] text-rad-cream leading-none"><%= @question.number %></span>
          </div>
          <% Array(@question.dt_references).each do |dt_ref| %>
            <span class="text-[11px] font-bold px-2.5 py-1 rounded-[6px] bg-rad-yellow text-rad-ink tracking-[0.04em]"><%= dt_ref %></span>
          <% end %>
          <% Array(@question.dr_references).each do |dr_ref| %>
            <span class="text-[11px] font-bold px-2.5 py-1 rounded-[6px] bg-rad-yellow text-rad-ink tracking-[0.04em]"><%= dr_ref %></span>
          <% end %>
        </div>
        <%# Question label %>
        <p class="flex-1 font-serif text-[19px] leading-[1.3] text-rad-text m-0 text-balance"><%= @question.label %></p>
      </div>
    </div>
```

- [ ] **Step 4: Run spec to verify it passes**

```bash
bundle exec rspec spec/requests/student/questions_spec.rb -e "serif card" --format documentation
```

Expected: 1 passing.

- [ ] **Step 5: Commit**

```bash
git add app/views/student/questions/show.html.erb
git commit -m "style(questions): Radical part header, context card, question card"
```

---

### Task 4: Reskin show.html.erb — desktop nav + mobile bottom bar

**Files:**
- Modify: `app/views/student/questions/show.html.erb` (lines 152–234)

- [ ] **Step 1: Write failing spec**

In `spec/requests/student/questions_spec.rb`, add:

```ruby
context "navigation styling" do
  let!(:q2) { create(:question, part: part, position: 2) }

  it "uses rad-red for next question button" do
    get student_question_path(access_code: classroom.access_code, subject_id: subject_obj.id, id: question.id)
    expect(response.body).to include("bg-rad-red")
    expect(response.body).to include("Question suivante")
  end
end
```

- [ ] **Step 2: Run spec to verify it fails**

```bash
bundle exec rspec spec/requests/student/questions_spec.rb -e "rad-red for next" --format documentation
```

Expected: 1 failure (bg-rad-red not yet in nav).

- [ ] **Step 3: Replace desktop nav (lines 152–182)**

Replace the desktop nav block in `show.html.erb`:

```erb
    <%# Desktop navigation (hidden on mobile — bottom bar handles it) %>
    <div class="hidden lg:flex justify-between items-center pt-4 border-t border-rad-rule mt-2">
      <% if prev_q %>
        <%= link_to "← Q#{prev_q.number}",
            prev_href,
            class: "text-rad-teal text-sm no-underline hover:opacity-75 transition-opacity" %>
      <% else %>
        <span></span>
      <% end %>

      <% if next_href && next_q %>
        <%= link_to "Question suivante →",
            next_href,
            class: "inline-flex items-center px-6 py-2.5 bg-rad-red text-rad-cream rounded-[14px] text-sm font-bold no-underline hover:opacity-90 transition-opacity" %>
      <% elsif params[:from] == "review" %>
        <%= link_to "Question suivante →",
            next_href,
            class: "inline-flex items-center px-6 py-2.5 bg-rad-red text-rad-cream rounded-[14px] text-sm font-bold no-underline hover:opacity-90 transition-opacity" %>
      <% elsif next_part_in_section && next_part_first_question %>
        <%= link_to end_of_part_label,
            student_question_path(access_code: params[:access_code], subject_id: @subject.id, id: next_part_first_question.id),
            class: "inline-flex items-center px-6 py-2.5 bg-rad-red text-rad-cream rounded-[14px] text-sm font-bold no-underline hover:opacity-90 transition-opacity" %>
      <% else %>
        <%= button_to end_of_part_label,
            student_subject_part_completion_path(access_code: params[:access_code], subject_id: @subject.id, part_id: @part.id),
            method: :post,
            class: "inline-flex items-center px-6 py-2.5 bg-rad-red text-rad-cream rounded-[14px] text-sm font-bold border-0 cursor-pointer hover:opacity-90 transition-opacity" %>
      <% end %>
    </div>
  </div>
```

- [ ] **Step 4: Replace mobile bottom bar (lines 185–234)**

Replace the mobile bottom bar block in `show.html.erb`:

```erb
  <%# Mobile bottom bar (hidden on lg+) %>
  <div class="lg:hidden fixed bottom-0 left-0 right-0 z-[var(--z-bottom-bar)] bg-rad-bg border-t border-rad-rule px-4 py-3 flex items-center gap-3">
    <% if prev_q %>
      <%= link_to prev_href,
          class: "flex-1 min-w-0 text-left text-sm text-rad-muted hover:text-rad-text truncate no-underline" do %>
        &larr; Q<%= prev_q.number %>
      <% end %>
    <% else %>
      <span class="flex-1"></span>
    <% end %>

    <% if @tutor_available %>
      <button type="button"
              data-controller="tutor-activator"
              data-tutor-activator-subject-id-value="<%= @subject.id %>"
              data-tutor-activator-question-id-value="<%= @question.id %>"
              data-tutor-activator-conversations-url-value="<%= student_conversations_path(access_code: params[:access_code]) %>"
              data-action="click->tutor-activator#activate"
              data-chat-drawer-toggle="true"
              aria-label="Ouvrir le tutorat IA"
              aria-expanded="false"
              aria-controls="tutor-chat-drawer"
              class="flex-shrink-0 inline-flex items-center gap-1.5 pl-2 pr-3 py-1.5 bg-rad-ink text-rad-cream border-0 rounded-full text-sm font-semibold cursor-pointer whitespace-nowrap shadow-[0_4px_12px_-4px_rgba(0,0,0,0.3)]">
        <span class="w-5 h-5 rounded-full bg-rad-red text-rad-cream flex items-center justify-center font-serif italic text-[11px] flex-shrink-0">T</span>
        Tibo
      </button>
    <% else %>
      <%= link_to "Activer le tuteur",
          student_settings_path(access_code: params[:access_code]),
          class: "flex-shrink-0 inline-flex items-center gap-1.5 px-3 py-1.5 bg-rad-paper text-rad-muted border border-rad-rule rounded-full text-xs font-medium whitespace-nowrap hover:bg-rad-raise transition-colors no-underline" %>
    <% end %>

    <% if next_href %>
      <%= link_to next_href,
          class: "flex-1 min-w-0 text-right text-sm font-bold text-rad-red truncate no-underline" do %>
        <%= next_q ? "Q#{next_q.number}" : (params[:from] == 'review' ? "Retour" : "Suivante") %> &rarr;
      <% end %>
    <% elsif next_part_in_section && next_part_first_question %>
      <%= link_to student_question_path(access_code: params[:access_code], subject_id: @subject.id, id: next_part_first_question.id),
          class: "flex-1 min-w-0 text-right text-sm font-bold text-rad-red truncate no-underline" do %>
        <%= end_of_part_mobile_label %>
      <% end %>
    <% else %>
      <div class="flex-1 min-w-0 text-right">
        <%= button_to end_of_part_mobile_label,
            student_subject_part_completion_path(access_code: params[:access_code], subject_id: @subject.id, part_id: @part.id),
            method: :post,
            class: "text-sm font-bold text-rad-red truncate border-0 bg-transparent cursor-pointer p-0" %>
      </div>
    <% end %>
  </div>

  <%= render "student/conversations/drawer",
             conversation: @conversation,
             question:     @question,
             access_code:  params[:access_code] %>
</div>
```

- [ ] **Step 5: Run spec to verify it passes**

```bash
bundle exec rspec spec/requests/student/questions_spec.rb -e "rad-red for next" --format documentation
```

Expected: 1 passing.

- [ ] **Step 6: Update tutor button selectors in existing spec**

In `spec/requests/student/questions_spec.rb`, the existing T200 specs check for `"💬 Tutorat"` — update them to check for `"Tibo"`:

Find lines like:
```ruby
expect(response.body).to include("💬 Tutorat")
expect(response.body).not_to include("💬 Tutorat")
```

Replace with:
```ruby
expect(response.body).to include("Tibo")
expect(response.body).not_to include("Tibo")
```

- [ ] **Step 7: Run full questions spec**

```bash
bundle exec rspec spec/requests/student/questions_spec.rb --format documentation
```

Expected: all passing.

- [ ] **Step 8: Commit**

```bash
git add app/views/student/questions/show.html.erb spec/requests/student/questions_spec.rb
git commit -m "style(questions): Radical desktop nav, mobile bottom bar, Tibo button"
```

---

### Task 5: Reskin _correction_button.html.erb

**Files:**
- Modify: `app/views/student/questions/_correction_button.html.erb`

- [ ] **Step 1: Write failing spec**

In `spec/requests/student/questions_spec.rb`, add:

```ruby
describe "correction button styling" do
  it "uses outlined rad-text style for correction button" do
    get student_question_path(access_code: classroom.access_code, subject_id: subject_obj.id, id: question.id)
    expect(response.body).to include("border-rad-text")
    expect(response.body).not_to include("from-indigo-500")
  end
end
```

- [ ] **Step 2: Run spec to verify it fails**

```bash
bundle exec rspec spec/requests/student/questions_spec.rb -e "outlined rad-text" --format documentation
```

Expected: 1 failure.

- [ ] **Step 3: Replace _correction_button.html.erb**

```erb
<%= turbo_frame_tag "question_#{question.id}_correction" do %>
  <% if question.answer %>
    <div class="flex flex-wrap items-center justify-center gap-4 mb-4">
      <%= button_to "Voir la correction",
          student_subject_question_correction_path(access_code: access_code, subject_id: subject.id, question_id: question.id),
          method: :post,
          data: { turbo_frame: "question_#{question.id}_correction" },
          class: "px-8 py-3 border border-rad-text text-rad-text bg-transparent rounded-[14px] text-[13.5px] font-bold cursor-pointer hover:bg-rad-raise transition-colors" %>
    </div>
  <% end %>
<% end %>
```

- [ ] **Step 4: Run spec to verify it passes**

```bash
bundle exec rspec spec/requests/student/questions_spec.rb -e "outlined rad-text" --format documentation
```

Expected: 1 passing.

- [ ] **Step 5: Commit**

```bash
git add app/views/student/questions/_correction_button.html.erb spec/requests/student/questions_spec.rb
git commit -m "style(questions): Radical correction button — outlined rad-text"
```

---

### Task 6: Reskin _correction.html.erb

**Files:**
- Modify: `app/views/student/questions/_correction.html.erb`

- [ ] **Step 1: Write failing spec**

In `spec/requests/student/questions_spec.rb`, add a block that reveals correction and checks Radical classes. First find existing correction reveal spec or add:

```ruby
describe "correction display (Radical)" do
  before do
    ss = student.student_sessions.find_or_create_by!(subject: subject_obj) do |s|
      s.mode = :autonomous; s.started_at = Time.current; s.last_activity_at = Time.current
    end
    ss.mark_answered!(question.id)
    ss.save!
  end

  it "renders correction with Radical green card" do
    get student_question_path(access_code: classroom.access_code, subject_id: subject_obj.id, id: question.id)
    expect(response.body).to include("bg-rad-green")
    expect(response.body).to include("pattern-madras")
  end

  it "renders data hints with yellow accent" do
    answer.update!(data_hints: [{ "source" => "DT1", "location" => "tableau", "value" => "30,5 L" }])
    get student_question_path(access_code: classroom.access_code, subject_id: subject_obj.id, id: question.id)
    expect(response.body).to include("bg-rad-yellow")
    expect(response.body).to include("Où trouver les données")
  end
end
```

- [ ] **Step 2: Run specs to verify they fail**

```bash
bundle exec rspec spec/requests/student/questions_spec.rb -e "Radical green" -e "yellow accent" --format documentation
```

Expected: 2 failures.

- [ ] **Step 3: Replace _correction.html.erb**

```erb
<div class="mt-4">

  <%# Big green answer card %>
  <div class="relative rounded-[20px] overflow-hidden mb-3 bg-rad-green" style="padding: 22px 22px 26px">
    <div class="pattern-madras absolute inset-0 opacity-[0.18]"></div>
    <div class="relative">
      <div class="flex items-center gap-2 text-[10.5px] tracking-[0.16em] uppercase font-bold text-rad-cream opacity-90 mb-2">
        <span>✓</span>
        <span>Réponse</span>
      </div>
      <% correction = question.answer&.correction_text.to_s %>
      <% if correction.length <= 60 %>
        <span class="font-serif text-[36px] text-rad-cream leading-none block"><%= correction %></span>
      <% else %>
        <p class="font-serif text-[20px] text-rad-cream leading-[1.4] m-0"><%= correction %></p>
      <% end %>
    </div>
  </div>

  <%# Explanation card %>
  <% if question.answer&.explanation_text.present? %>
    <div class="bg-rad-paper border border-rad-rule rounded-[18px] overflow-hidden mb-3">
      <div class="px-[18px] py-[14px] border-b border-rad-rule flex items-center gap-2.5 relative">
        <span class="absolute left-0 top-0 bottom-0 w-1 bg-rad-teal rounded-r-sm"></span>
        <div class="w-[22px] h-[22px] rounded-full bg-rad-teal flex items-center justify-center font-serif italic text-[13px] text-rad-cream font-medium flex-shrink-0">=</div>
        <span class="font-serif text-[15px] text-rad-text">
          <% if question.answer_type == "calculation" %>
            Détail du calcul
          <% else %>
            Pourquoi
          <% end %>
        </span>
      </div>
      <div class="px-[18px] py-[16px]">
        <% if question.answer_type == "calculation" %>
          <p class="font-mono text-[14px] leading-[1.7] text-rad-text m-0"><%= question.answer.explanation_text %></p>
        <% else %>
          <p class="font-serif text-[17px] leading-[1.5] text-rad-text m-0"><%= question.answer.explanation_text %></p>
        <% end %>
      </div>
    </div>
  <% end %>

  <%# Data hints %>
  <% if question.answer&.data_hints.present? %>
    <div class="bg-rad-paper border border-rad-rule rounded-[18px] overflow-hidden mb-3">
      <div class="px-[18px] py-[14px] border-b border-rad-rule flex items-center gap-2.5 relative">
        <span class="absolute left-0 top-0 bottom-0 w-1 bg-rad-yellow rounded-r-sm"></span>
        <div class="w-[22px] h-[22px] rounded-full bg-rad-yellow flex items-center justify-center font-serif italic text-[13px] text-rad-ink font-medium flex-shrink-0">i</div>
        <span class="font-serif text-[15px] text-rad-text">Où trouver les données ?</span>
      </div>
      <% question.answer.data_hints.each_with_index do |hint, i| %>
        <div class="px-[18px] py-[14px] flex gap-3 items-start <%= i > 0 ? 'border-t border-rad-rule' : '' %>">
          <span class="flex-shrink-0 text-[11px] font-bold px-2 py-[3px] rounded-[6px] tracking-[0.04em] h-fit
                        <%= i == 0 ? 'bg-rad-yellow text-rad-ink' : 'bg-rad-raise border border-rad-rule text-rad-text' %>">
            <%= hint_source_label(hint["source"]) %>
          </span>
          <div class="flex-1 min-w-0">
            <div class="text-[13px] text-rad-muted mb-1"><%= hint["location"] %></div>
            <% if hint["value"].present? %>
              <div class="font-mono text-[13px] text-rad-text font-medium"><%= hint["value"] %></div>
            <% end %>
          </div>
        </div>
      <% end %>
    </div>
  <% end %>

  <%# Key concepts %>
  <% if question.answer&.key_concepts.present? %>
    <div class="bg-rad-paper border border-rad-rule rounded-[18px] px-[18px] py-[14px] mb-3">
      <div class="text-[10.5px] tracking-[0.16em] uppercase text-rad-muted font-bold mb-2.5">Concepts à réviser</div>
      <div class="flex flex-wrap gap-1.5">
        <% question.answer.key_concepts.each do |concept| %>
          <span class="font-serif italic text-[14px] border border-rad-rule bg-rad-paper text-rad-text rounded-full px-3 py-1"><%= concept %></span>
        <% end %>
      </div>
    </div>
  <% end %>

  <%# Documents correction %>
  <% if subject.dr_corrige_file.attached? || subject.questions_corrigees_file.attached? %>
    <div class="bg-rad-paper border border-rad-rule rounded-[18px] px-[18px] py-[14px] mb-3">
      <p class="text-rad-muted text-[10.5px] uppercase tracking-wide font-bold mb-2">Documents correction</p>
      <% if subject.dr_corrige_file.attached? %>
        <%= link_to "DR corrigé ↗",
            rails_blob_path(subject.dr_corrige_file, disposition: "inline"),
            target: "_blank",
            class: "block text-rad-teal text-sm my-0.5 no-underline hover:opacity-75 transition-opacity" %>
      <% end %>
      <% if subject.questions_corrigees_file.attached? %>
        <%= link_to "Questions corrigées ↗",
            rails_blob_path(subject.questions_corrigees_file, disposition: "inline"),
            target: "_blank",
            class: "block text-rad-teal text-sm my-0.5 no-underline hover:opacity-75 transition-opacity" %>
      <% end %>
    </div>
  <% end %>

  <%# Expliquer la correction (tutored mode only) %>
  <% if defined?(session_record) && session_record&.tutored? %>
    <div class="text-center mt-3">
      <button type="button"
              class="text-rad-teal text-sm underline underline-offset-2 cursor-pointer hover:opacity-75 transition-opacity border-0 bg-transparent"
              data-action="click->chat-drawer#open"
              data-chat-drawer-toggle="true"
              aria-controls="tutor-chat-drawer">
        Expliquer la correction
      </button>
    </div>
  <% end %>

</div>
```

- [ ] **Step 4: Run correction specs to verify they pass**

```bash
bundle exec rspec spec/requests/student/questions_spec.rb -e "Radical green" -e "yellow accent" --format documentation
```

Expected: 2 passing.

- [ ] **Step 5: Commit**

```bash
git add app/views/student/questions/_correction.html.erb spec/requests/student/questions_spec.rb
git commit -m "style(questions): Radical correction — green card, data hints, concepts"
```

---

### Task 7: Reskin _sidebar.html.erb + _sidebar_part.html.erb

**Files:**
- Modify: `app/views/student/questions/_sidebar.html.erb`
- Modify: `app/views/student/questions/_sidebar_part.html.erb`

No new specs needed — sidebar is inside the `<aside>` already tested for `bg-rad-paper` in Task 1.

- [ ] **Step 1: Replace _sidebar.html.erb CSS classes**

Replace all occurrences of dark/slate classes, keeping all ERB logic and links:

Changes to make (search → replace):
- `text-slate-500` → `text-rad-muted`
- `text-blue-400` / `text-blue-300` → `text-rad-teal` / `text-rad-teal`
- `text-amber-400` / `text-amber-300` → `text-rad-yellow` / `text-rad-yellow`
- `text-emerald-400` / `text-emerald-300` → `text-rad-green` / `text-rad-green`
- `border-slate-700` → `border-rad-rule`
- `text-slate-400` → `text-rad-muted`
- `hover:text-indigo-300` → `hover:text-rad-teal`
- `hover:bg-slate-800` → `hover:bg-rad-raise`
- `hover:text-slate-200` → `hover:text-rad-text`

Full replacement of `_sidebar.html.erb`:

```erb
<%# Sidebar content — documents, presentations, parts/questions, settings %>
<div class="p-4">

  <%# Documents %>
  <% if subject.new_format? %>
    <p class="text-rad-muted text-[10px] uppercase tracking-wide mb-2">Documents</p>
    <%= link_to rails_blob_path(subject.subject_pdf, disposition: "inline"),
        target: "_blank",
        class: "flex items-center gap-1.5 text-rad-teal text-xs my-1 no-underline hover:opacity-75 transition-opacity" do %>
      <%= render(BadgeComponent.new(color: :blue, label: "PDF")) %>
      <span>Sujet complet</span>
    <% end %>
    <% if session_record.answered?(current_question.id) %>
      <%= link_to rails_blob_path(subject.correction_pdf, disposition: "inline"),
          target: "_blank",
          class: "flex items-center gap-1.5 text-rad-green text-xs my-1 no-underline hover:opacity-75 transition-opacity" do %>
        <%= render(BadgeComponent.new(color: :emerald, label: "PDF")) %>
        <span>Corrigé complet</span>
      <% end %>
    <% end %>
    <hr class="border-rad-rule my-3">
  <% else %>
    <% has_docs = subject.dt_file.attached? || subject.dr_vierge_file.attached? %>
    <% if has_docs %>
      <p class="text-rad-muted text-[10px] uppercase tracking-wide mb-2">Documents</p>
      <% if subject.dt_file.attached? %>
        <%= link_to rails_blob_path(subject.dt_file, disposition: "inline"),
            target: "_blank",
            class: "flex items-center gap-1.5 text-rad-teal text-xs my-1 no-underline hover:opacity-75 transition-opacity" do %>
          <%= render(BadgeComponent.new(color: :blue, label: "DT")) %>
          <span>Documents Techniques</span>
        <% end %>
      <% end %>
      <% if subject.dr_vierge_file.attached? %>
        <%= link_to rails_blob_path(subject.dr_vierge_file, disposition: "attachment"),
            class: "flex items-center gap-1.5 text-rad-yellow text-xs my-1 no-underline hover:opacity-75 transition-opacity" do %>
          <%= render(BadgeComponent.new(color: :amber, label: "DR")) %>
          <span>DR vierge</span>
        <% end %>
      <% end %>
      <% if session_record.answered?(current_question.id) %>
        <% if subject.dr_corrige_file.attached? %>
          <%= link_to rails_blob_path(subject.dr_corrige_file, disposition: "inline"),
              target: "_blank",
              class: "flex items-center gap-1.5 text-rad-green text-xs my-1 no-underline hover:opacity-75 transition-opacity" do %>
            <%= render(BadgeComponent.new(color: :emerald, label: "DR")) %>
            <span>DR corrigé</span>
          <% end %>
        <% end %>
      <% end %>
      <hr class="border-rad-rule my-3">
    <% end %>
  <% end %>

  <%# Context — presentations %>
  <% has_common_presentation = subject.common_presentation.present? %>
  <% has_specific_presentation = subject.specific_presentation.present? %>
  <% if has_common_presentation || has_specific_presentation %>
    <p class="text-rad-muted text-[10px] uppercase tracking-wide mb-2">Contexte</p>
    <% if has_common_presentation %>
      <%= link_to student_subject_path(access_code: access_code, id: subject.id),
          class: "flex items-center gap-1.5 text-rad-muted text-xs my-1 no-underline hover:text-rad-teal transition-colors" do %>
        <span>📋</span>
        <span>Présentation commune</span>
      <% end %>
    <% end %>
    <% if has_specific_presentation %>
      <%
        first_specific = parts.sort_by(&:position).find { |p| p.section_type == "specific" }
        specific_q = first_specific&.questions&.kept&.order(:position)&.first
      %>
      <% if specific_q %>
        <%= link_to student_question_path(access_code: access_code, subject_id: subject.id, id: specific_q.id, show_specific_presentation: true),
            class: "flex items-center gap-1.5 text-rad-muted text-xs my-1 no-underline hover:text-rad-teal transition-colors" do %>
          <span>📋</span>
          <span>Présentation spécifique</span>
        <% end %>
      <% end %>
    <% end %>
    <hr class="border-rad-rule my-3">
  <% end %>

  <%# All parts %>
  <%
    ordered_parts = parts.sort_by(&:position)
    common_parts_list = common_parts(ordered_parts)
    specific_parts_list = specific_parts(ordered_parts)
    show_section_headers = common_parts_list.any? && specific_parts_list.any?
  %>

  <% if show_section_headers && common_parts_list.any? %>
    <p class="text-rad-muted text-[10px] uppercase tracking-wide mb-1 mt-2 font-semibold px-2">Partie commune</p>
  <% end %>
  <% common_parts_list.each do |p| %>
    <%= render "student/questions/sidebar_part",
        part: p,
        current_part: current_part,
        current_question: current_question,
        session_record: session_record,
        subject: subject,
        access_code: access_code %>
  <% end %>

  <% if show_section_headers && specific_parts_list.any? %>
    <p class="text-rad-muted text-[10px] uppercase tracking-wide mb-1 mt-4 font-semibold px-2">Partie spécifique</p>
  <% end %>
  <% specific_parts_list.each do |p| %>
    <%= render "student/questions/sidebar_part",
        part: p,
        current_part: current_part,
        current_question: current_question,
        session_record: session_record,
        subject: subject,
        access_code: access_code %>
  <% end %>

  <hr class="border-rad-rule my-3">

  <%= link_to student_settings_path(access_code: access_code),
      class: "flex items-center gap-1.5 text-rad-muted text-xs no-underline px-2 py-1.5 rounded-lg hover:text-rad-text hover:bg-rad-raise transition-colors" do %>
    <span>⚙</span>
    <span>Réglages</span>
  <% end %>
</div>
```

- [ ] **Step 2: Replace _sidebar_part.html.erb CSS classes**

```erb
<%
  is_active = part == current_part
  part_questions = part.questions.kept.order(:position)
  part_answered = session_record.answered_count_for(part_questions)
%>

<% if is_active %>
  <p class="text-rad-teal text-[10px] uppercase tracking-wide mb-1 mt-2 font-semibold px-2">
    Partie <%= part.number %>
    <span class="text-rad-muted font-normal">(<%= part_answered %>/<%= part_questions.size %>)</span>
  </p>
  <% part_questions.each do |q| %>
    <% answered = session_record.answered?(q.id) %>
    <% is_current = q == current_question %>
    <%= link_to student_question_path(access_code: access_code, subject_id: subject.id, id: q.id),
        class: "flex items-center gap-1.5 px-2 py-1.5 my-0.5 rounded-lg text-xs no-underline transition-colors #{is_current ? 'bg-rad-teal/10 text-rad-text' : 'text-rad-muted hover:bg-rad-raise hover:text-rad-text'}",
        data: { action: "click->sidebar#close" } do %>
      <% if answered %>
        <span class="text-rad-green text-[10px]">✓</span>
      <% elsif is_current %>
        <span class="text-rad-teal text-[10px]">◉</span>
      <% else %>
        <span class="text-rad-muted text-[10px]">○</span>
      <% end %>
      <span>Q<%= q.number %></span>
    <% end %>
  <% end %>
<% else %>
  <%= link_to student_subject_path(access_code: access_code, id: subject.id, part_id: part.id),
      class: "flex items-center justify-between px-2 py-1.5 mt-2 my-0.5 rounded-lg text-xs text-rad-muted no-underline hover:bg-rad-raise hover:text-rad-text transition-colors",
      data: { action: "click->sidebar#close" } do %>
    <span>Partie <%= part.number %></span>
    <span class="text-rad-muted text-[10px]"><%= part_answered %>/<%= part_questions.size %></span>
  <% end %>
<% end %>
```

- [ ] **Step 3: Run full spec suite to verify no regression**

```bash
bundle exec rspec spec/requests/student/questions_spec.rb spec/features/student/subject_workflow_spec.rb --format documentation
```

Expected: all passing.

- [ ] **Step 4: Commit**

```bash
git add app/views/student/questions/_sidebar.html.erb app/views/student/questions/_sidebar_part.html.erb
git commit -m "style(questions): Radical sidebar — rad-paper surface, muted links, teal active"
```

---

### Task 8: Rebuild Tailwind CSS + full test run + PR

**Files:**
- No new code — verification only

- [ ] **Step 1: Rebuild Tailwind to include all new rad-* utility classes**

```bash
bin/rails tailwindcss:build
```

Expected: `Done in Xms` — no errors.

- [ ] **Step 2: Run full RSpec suite**

```bash
bundle exec rspec spec/requests/student/ spec/features/student/ --format documentation
```

Expected: all passing. If any spec fails due to selector mismatch (e.g. `"💬 Tutorat"` still in another spec file), fix the selector.

- [ ] **Step 3: Check for any remaining `dark:` classes in modified files**

```bash
grep -n "dark:" app/views/student/questions/show.html.erb app/views/student/questions/_correction.html.erb app/views/student/questions/_sidebar.html.erb app/views/student/questions/_sidebar_part.html.erb
```

Expected: no output. If any remain, remove them.

- [ ] **Step 4: Verify `specialty_label` method exists**

```bash
grep -n "def specialty_label\|specialty_label" app/models/subject.rb
```

If not found, replace `@subject.specialty_label` in show.html.erb (Task 2) with:
```erb
<%= [@subject.exam_type&.upcase, @subject.specialty&.to_s&.upcase].compact.join(" · ") %>
```

- [ ] **Step 5: Create branch + push + open PR**

```bash
git checkout -b 055-questions-show-radical
git push -u origin 055-questions-show-radical
```

Then open PR:
```bash
gh pr create --title "style(questions): Radical reskin — questions/show + correction" --body "$(cat <<'EOF'
## Summary
- Reskin `student/questions/show.html.erb` to Radical design system (cream bg, serif typography, rad-* tokens)
- Reskin `_correction.html.erb` — green card with madras overlay, data hints with yellow accent, serif concepts pills
- Reskin `_correction_button.html.erb` — outlined rad-text style
- Reskin `_sidebar.html.erb` + `_sidebar_part.html.erb` — rad-paper surface, muted links, teal active state
- Update request specs: Tibo button selectors, Radical class assertions

## Test plan
- [ ] All request specs passing: `bundle exec rspec spec/requests/student/questions_spec.rb`
- [ ] All feature specs passing: `bundle exec rspec spec/features/student/subject_workflow_spec.rb`
- [ ] No `dark:` classes in modified files
- [ ] Tailwind rebuilt: `bin/rails tailwindcss:build`
- [ ] Visual check: open a question page locally, verify cream background, Tibo button, correction card

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

---

## Notes for the implementer

1. **`@subject.specialty_label`** — verify this method exists before using it. See Task 2 Step 3.
2. **`_correction_button.html.erb` vs inline turbo_frame** — `show.html.erb` line 137 has an inline turbo_frame (not the partial). The `_correction_button.html.erb` partial is rendered from a different path (e.g. sidebar). Update both: the inline block in `show.html.erb` (Task 1–4) AND the `_correction_button.html.erb` partial (Task 5).
3. **Branch**: create branch `055-questions-show-radical` before first commit or in Task 8 Step 5. All task commits land on this branch.
4. **`hint_source_label` helper** — used in `_correction.html.erb`. This helper already exists (it was in the original partial). Don't remove the call.
