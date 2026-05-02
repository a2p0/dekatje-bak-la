# subjects/show — Radical Design Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reskin all 6 conditional states of `subjects#show` to the Radical design system (cream/balisier/teal/yellow palette, Fraunces + Inter typography).

**Architecture:** Pure view-layer reskin — no controller changes, no migrations. 2 new shared partials (`_stripes`, `_subject_header`), 1 new Stimulus controller (`scope-selector`), and reskin of 5 existing partials + the `show.html.erb` else-block. Existing Capybara feature specs must continue passing; add new UI-targeting specs for the redesigned elements.

**Tech Stack:** Rails 8 ERB partials, Tailwind 4 (rad-* tokens from PR #75), Stimulus (auto-loaded via `eagerLoadControllersFrom`), RSpec/Capybara feature specs.

---

## File Map

| Action | File |
|---|---|
| Create | `app/views/student/subjects/_stripes.html.erb` |
| Create | `app/views/student/subjects/_subject_header.html.erb` |
| Create | `app/javascript/controllers/scope_selector_controller.js` |
| Replace | `app/views/student/subjects/_scope_selection.html.erb` |
| Replace | `app/views/student/tutor/_tutor_banner.html.erb` |
| Replace | `app/views/student/subjects/_part_row.html.erb` |
| Replace | `app/views/student/subjects/_specific_presentation.html.erb` |
| Replace | `app/views/student/subjects/_unanswered_questions.html.erb` |
| Replace | `app/views/student/subjects/_completion.html.erb` |
| Modify | `app/views/student/subjects/show.html.erb` (else-block + relecture) |
| Modify | `spec/features/student/subject_workflow_spec.rb` (update selectors + add UI specs) |

---

## Task 1: Create shared partials `_stripes` and `_subject_header`

**Files:**
- Create: `app/views/student/subjects/_stripes.html.erb`
- Create: `app/views/student/subjects/_subject_header.html.erb`

- [ ] **Step 1: Create `_stripes.html.erb`**

```erb
<div class="flex h-1.5" aria-hidden="true">
  <div class="flex-1 bg-rad-red"></div>
  <div class="flex-1 bg-rad-yellow"></div>
  <div class="flex-1 bg-rad-teal"></div>
  <div class="flex-1 bg-rad-ink"></div>
</div>
```

- [ ] **Step 2: Create `_subject_header.html.erb`**

Locals: `back_path` (String), `suptitle` (String), `title` (String).

```erb
<div class="px-5 py-3.5 flex items-center justify-between">
  <%= link_to back_path, class: "text-rad-text text-2xl leading-none no-underline" do %>‹<% end %>
  <div class="text-center flex-1 px-2">
    <% if suptitle.present? %>
      <div class="text-[10.5px] tracking-[0.16em] uppercase text-rad-muted font-bold"><%= suptitle %></div>
    <% end %>
    <span class="font-serif text-sm italic text-rad-text leading-none"><%= title %></span>
  </div>
  <span class="text-rad-text text-lg leading-none">≡</span>
</div>
```

- [ ] **Step 3: Commit**

```bash
git add app/views/student/subjects/_stripes.html.erb app/views/student/subjects/_subject_header.html.erb
git commit -m "feat(design): add _stripes and _subject_header Radical partials"
```

---

## Task 2: Create `scope_selector` Stimulus controller

**Files:**
- Create: `app/javascript/controllers/scope_selector_controller.js`

No test needed (Stimulus controller unit testing is out of scope; end-to-end behaviour covered by feature spec in Task 10).

- [ ] **Step 1: Create the controller**

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["option", "form", "input"]

  connect() {
    const defaultOption = this.optionTargets.find(o => o.dataset.value === "full")
      || this.optionTargets[0]
    if (defaultOption) this.selectOption(defaultOption)
  }

  select(event) {
    this.selectOption(event.currentTarget)
  }

  submit() {
    this.formTarget.requestSubmit()
  }

  selectOption(card) {
    this.optionTargets.forEach(o => o.dataset.selected = "false")
    card.dataset.selected = "true"
    if (this.hasInputTarget) this.inputTarget.value = card.dataset.value
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add app/javascript/controllers/scope_selector_controller.js
git commit -m "feat(design): add scope_selector Stimulus controller"
```

---

## Task 3: Reskin `_scope_selection.html.erb`

**Files:**
- Replace: `app/views/student/subjects/_scope_selection.html.erb`

Existing locals (unchanged): `subject`, `session_record`, `access_code`.

The existing partial uses 3 separate `button_to` forms that submit immediately on click. The new version uses radio cards + a single hidden form submitted by a Stimulus-driven "Commencer" button.

- [ ] **Step 1: Replace the partial**

```erb
<div data-controller="scope-selector">
  <%= render "student/subjects/stripes" %>
  <%= render "student/subjects/subject_header",
        back_path: student_root_path(access_code: access_code),
        suptitle: "#{subject.exam_type&.upcase} · #{subject.specialty&.upcase}",
        title: subject.title %>

  <div class="px-5 pb-5">
    <p class="font-serif text-xl text-rad-text mb-1">
      Quel périmètre veux-tu réviser<span class="text-rad-red">?</span>
    </p>
    <p class="text-sm text-rad-muted leading-relaxed">
      Ce sujet comporte une partie commune (TC) et une partie spécifique <%= subject.specialty&.upcase %>.
    </p>
  </div>

  <div class="px-4 flex flex-col gap-2.5">
    <%# Option : TC + Spécifique (full) %>
    <button type="button"
            data-scope-selector-target="option"
            data-value="full"
            data-action="click->scope-selector#select"
            data-selected="true"
            class="group text-left w-full px-[18px] py-4 rounded-[18px] bg-rad-paper border-2 border-rad-red relative overflow-hidden transition-all
                   data-[selected=false]:border data-[selected=false]:border-rad-rule">
      <span class="absolute left-0 top-0 bottom-0 w-[5px] bg-rad-red group-data-[selected=false]:hidden"></span>
      <div class="flex items-center justify-between gap-2.5">
        <div>
          <span class="font-serif text-base block mb-1">TC + Spécifique <%= subject.specialty&.upcase %></span>
          <span class="text-xs text-rad-muted">Toutes les parties · 20 pts · 4h</span>
        </div>
        <div class="text-right flex-shrink-0">
          <span class="font-serif text-2xl text-rad-red leading-none block">20</span>
          <span class="text-[10px] text-rad-muted uppercase tracking-wider">pts</span>
        </div>
      </div>
    </button>

    <%# Option : Tronc commun seul %>
    <button type="button"
            data-scope-selector-target="option"
            data-value="common_only"
            data-action="click->scope-selector#select"
            data-selected="false"
            class="group text-left w-full px-[18px] py-4 rounded-[18px] bg-rad-paper border border-rad-rule relative overflow-hidden transition-all
                   data-[selected=true]:border-2 data-[selected=true]:border-rad-teal">
      <span class="absolute left-0 top-0 bottom-0 w-[5px] bg-rad-teal hidden group-data-[selected=true]:block"></span>
      <div class="flex items-center justify-between gap-2.5">
        <div>
          <span class="font-serif text-base block mb-1">Tronc commun seul</span>
          <span class="text-xs text-rad-muted">Parties communes · 12 pts · 2h30</span>
        </div>
        <div class="text-right flex-shrink-0">
          <span class="font-serif text-2xl text-rad-teal leading-none block">12</span>
          <span class="text-[10px] text-rad-muted uppercase tracking-wider">pts</span>
        </div>
      </div>
    </button>

    <%# Option : Spécifique seul %>
    <button type="button"
            data-scope-selector-target="option"
            data-value="specific_only"
            data-action="click->scope-selector#select"
            data-selected="false"
            class="group text-left w-full px-[18px] py-4 rounded-[18px] bg-rad-paper border border-rad-rule relative overflow-hidden transition-all
                   data-[selected=true]:border-2 data-[selected=true]:border-rad-yellow">
      <span class="absolute left-0 top-0 bottom-0 w-[5px] bg-rad-yellow hidden group-data-[selected=true]:block"></span>
      <div class="flex items-center justify-between gap-2.5">
        <div>
          <span class="font-serif text-base block mb-1">Spécifique <%= subject.specialty&.upcase %> seul</span>
          <span class="text-xs text-rad-muted">Partie spécifique · 8 pts · 1h30</span>
        </div>
        <div class="text-right flex-shrink-0">
          <span class="font-serif text-2xl text-rad-yellow leading-none block">8</span>
          <span class="text-[10px] text-rad-muted uppercase tracking-wider">pts</span>
        </div>
      </div>
    </button>
  </div>

  <%# Hidden form — submitted by the Commencer button %>
  <%= form_with url: student_subject_scope_selection_path(access_code: access_code, subject_id: subject.id),
                method: :patch,
                data: { scope_selector_target: "form" } do |f| %>
    <%= f.hidden_field :part_filter, value: "full", data: { scope_selector_target: "input" } %>
  <% end %>

  <%# Sticky CTA %>
  <div class="sticky bottom-0 px-4 pb-8 pt-3 bg-rad-bg border-t border-rad-rule">
    <button type="button"
            data-action="click->scope-selector#submit"
            class="w-full py-3.5 rounded-[14px] bg-rad-red text-rad-cream text-[13.5px] font-bold border-0 cursor-pointer">
      Commencer →
    </button>
  </div>
</div>
```

- [ ] **Step 2: Commit the partial only**

Do NOT edit the spec file yet — all spec selector updates are batched in Task 10. This avoids intermediate rspec failures from partially-updated specs.

```bash
git add app/views/student/subjects/_scope_selection.html.erb
git commit -m "feat(design): reskin _scope_selection to Radical — radio cards + Stimulus"
```

---

## Task 4: Reskin `_tutor_banner.html.erb`

**Files:**
- Replace: `app/views/student/tutor/_tutor_banner.html.erb`

Existing locals (unchanged): `tutor_status`, `access_code`.

- [ ] **Step 1: Replace the partial**

```erb
<div id="tutor-activation-banner"
     class="mx-4 mb-4 px-3.5 py-3 rounded-[14px] bg-rad-raise border border-rad-rule flex items-center gap-2.5">
  <div class="w-8 h-8 rounded-full bg-rad-red flex items-center justify-center flex-shrink-0">
    <span class="font-serif italic text-rad-cream text-sm">T</span>
  </div>
  <div class="flex-1 min-w-0">
    <% if tutor_status == :active %>
      <div class="text-[13px] font-semibold text-rad-text">Tibo actif</div>
      <div class="text-[11.5px] text-rad-muted flex items-center gap-1.5">
        <span class="w-1.5 h-1.5 rounded-full bg-rad-teal inline-block"></span>
        Ton tuteur IA t'accompagne sur ce sujet
      </div>
    <% elsif tutor_status == :available %>
      <div class="text-[13px] font-semibold text-rad-text">Tibo disponible</div>
      <div class="text-[11.5px] text-rad-muted">Ton tuteur IA t'accompagne sur ce sujet</div>
    <% else %>
      <div class="text-[13px] font-semibold text-rad-text">Tibo indisponible</div>
      <div class="text-[11.5px] text-rad-muted">
        <%= link_to "Paramétrer →", student_settings_path(access_code: access_code),
            class: "text-rad-teal no-underline" %>
      </div>
    <% end %>
  </div>
  <% if tutor_status == :available %>
    <%= link_to student_settings_path(access_code: access_code),
        class: "flex-shrink-0 text-xs font-bold px-3 py-1.5 rounded-full bg-rad-ink text-rad-cream no-underline" do %>
      Activer
    <% end %>
  <% end %>
</div>
```

- [ ] **Step 2: Commit**

```bash
git add app/views/student/tutor/_tutor_banner.html.erb
git commit -m "feat(design): reskin _tutor_banner to Radical"
```

---

## Task 5: Reskin `_part_row.html.erb`

**Files:**
- Replace: `app/views/student/subjects/_part_row.html.erb`

Existing locals (unchanged): `part`, `session_record`.

- [ ] **Step 1: Replace the partial**

```erb
<%
  is_done   = session_record.part_completed?(part.id)
  total_q   = part.questions.kept.size
  answered  = part.questions.kept.count { |q| session_record.answered?(q.id) }
  is_active = !is_done && answered > 0
  pct       = total_q > 0 ? (answered * 100 / total_q) : 0
  section_color = part.section_type == "specific" ? "bg-rad-yellow" : "bg-rad-teal"
  accent_color  = is_done ? "bg-rad-green" : is_active ? "bg-rad-red" : section_color
  border_class  = is_active ? "border-2 border-rad-red" : "border border-rad-rule"
%>
<div class="relative overflow-hidden rounded-[16px] bg-rad-paper <%= border_class %> px-4 py-3.5 mb-2"
     data-part-id="<%= part.id %>"
     data-part-completed="<%= is_done %>">
  <span class="absolute left-0 top-0 bottom-0 w-1 <%= accent_color %>"></span>
  <div class="flex items-center gap-2.5">
    <div class="w-[38px] h-[38px] rounded-[10px] flex-shrink-0 flex items-center justify-center
                <%= is_done ? 'bg-rad-green' : is_active ? 'bg-rad-red' : 'bg-rad-raise' %>">
      <% if is_done %>
        <span class="text-rad-cream text-base">✓</span>
      <% else %>
        <span class="font-serif text-[15px] <%= is_active ? 'text-rad-cream' : 'text-rad-muted' %>">
          <%= part.number %>
        </span>
      <% end %>
    </div>
    <div class="flex-1 min-w-0">
      <div class="text-[13.5px] font-semibold text-rad-text mb-0.5"><%= part.title %></div>
      <div class="text-[11.5px] text-rad-muted">
        <%= answered %>/<%= total_q %> questions · <%= part.questions.kept.sum(:points) %> pts
      </div>
    </div>
    <% if is_active %>
      <span class="flex-shrink-0 text-[10.5px] font-bold px-2 py-1 rounded-full bg-rad-red text-rad-cream">
        En cours
      </span>
    <% end %>
  </div>
  <% if is_active && pct > 0 %>
    <div class="mt-2.5 h-[3px] rounded-full bg-rad-rule overflow-hidden">
      <div class="h-full bg-rad-red rounded-full" style="width: <%= pct %>%"></div>
    </div>
  <% end %>
</div>
```

Note: `data-part-id` and `data-part-completed` are preserved (used in existing feature spec `find("[data-part-id='#{specific_part.id}']")`).

- [ ] **Step 2: Commit the partial only**

All spec selector updates are batched in Task 10.

```bash
git add app/views/student/subjects/_part_row.html.erb
git commit -m "feat(design): reskin _part_row to Radical — accent bars, progress, En cours badge"
```

---

## Task 6: Reskin `_specific_presentation.html.erb`

**Files:**
- Replace: `app/views/student/subjects/_specific_presentation.html.erb`

Existing locals (unchanged): `subject`, `first_question`, `session_record`, `access_code`.

Note: `subject.specific_points`, `subject.specific_questions`, and `subject.specialty_label` may not exist as methods. Use inline calculations instead.

- [ ] **Step 1: Check which methods exist on Subject**

```bash
grep -n "def specific_points\|def specific_questions\|def specialty_label" app/models/subject.rb
```

If they don't exist, use the inline fallbacks shown in Step 2.

- [ ] **Step 2: Replace the partial**

Use inline calculations for stats (no new model methods needed):

```erb
<%= render "student/subjects/stripes" %>
<%= render "student/subjects/subject_header",
      back_path: student_subject_path(access_code: access_code, id: subject.id),
      suptitle: "Partie spécifique · #{subject.specialty&.upcase}",
      title: subject.title %>

<%
  specific_parts = subject.parts.where(section_type: :specific)
  specific_pts   = specific_parts.joins(:questions).merge(Question.kept).sum("questions.points")
  specific_q_cnt = specific_parts.joins(:questions).merge(Question.kept).count
%>

<%# Hero card teal with pattern madras %>
<div class="mx-4 mt-3 rounded-[20px] overflow-hidden relative bg-rad-teal px-6 py-7">
  <div class="pattern-madras absolute inset-0 opacity-15 pointer-events-none"></div>
  <div class="relative">
    <div class="text-[10.5px] font-bold tracking-[0.18em] uppercase text-white/70 mb-2.5">
      Parties spécifiques · <%= subject.specialty&.upcase %>
    </div>
    <span class="font-serif text-2xl text-rad-cream leading-snug block">
      <%= subject.specialty&.humanize %>
    </span>
    <div class="mt-4 flex gap-5">
      <% [
        [specific_pts.to_s,   "barème"],
        [specific_q_cnt.to_s, "questions"],
        ["1h30",              "estimé"]
      ].each do |val, lbl| %>
        <div class="text-center">
          <div class="font-serif text-[22px] text-rad-cream leading-none"><%= val %></div>
          <div class="text-[10px] text-white/65 uppercase tracking-[0.1em] mt-0.5"><%= lbl %></div>
        </div>
      <% end %>
    </div>
  </div>
</div>

<%# Context block — yellow bar %>
<% if subject.specific_presentation.present? %>
  <div class="mx-4 mt-3.5 rounded-[16px] bg-rad-paper border border-rad-rule px-[18px] py-4 relative overflow-hidden">
    <span class="absolute left-0 top-0 bottom-0 w-1 bg-rad-yellow"></span>
    <div class="text-[10.5px] tracking-[0.14em] uppercase text-rad-muted font-bold mb-2">Contexte spécifique</div>
    <p class="text-sm leading-relaxed text-rad-muted"><%= subject.specific_presentation %></p>
  </div>
<% end %>

<%# DT tiles for the specific section %>
<% specific_dts = subject.technical_documents.where(doc_type: "DT").order(:number) %>
<% if specific_dts.any? %>
  <div class="mx-4 mt-3 flex gap-2">
    <% specific_dts.each do |dt| %>
      <div class="flex-1 px-3 py-2.5 rounded-[12px] bg-rad-paper border border-dashed border-rad-rule text-center">
        <span class="font-serif text-sm text-rad-yellow block">DT<%= dt.number %></span>
        <span class="text-[10.5px] text-rad-muted">PDF</span>
      </div>
    <% end %>
  </div>
<% end %>

<%# Sticky bar %>
<div class="sticky bottom-0 px-4 pb-8 pt-3 bg-rad-bg border-t border-rad-rule mt-6 flex gap-2.5">
  <%= link_to student_subject_path(access_code: access_code, id: subject.id),
      class: "flex-1 py-3.5 rounded-[14px] border-[1.5px] border-rad-text bg-transparent text-rad-text text-[13px] font-bold text-center no-underline" do %>
    ← Parties
  <% end %>
  <% if first_question %>
    <%= link_to student_question_path(access_code: access_code, subject_id: subject.id, id: first_question.id, mark_specific_seen: true),
        class: "flex-[1.5] py-3.5 rounded-[14px] bg-rad-red text-rad-cream text-[13px] font-bold text-center no-underline" do %>
      Commencer →
    <% end %>
  <% end %>
</div>
```

- [ ] **Step 3: Commit the partial only**

All spec selector updates are batched in Task 10.

```bash
git add app/views/student/subjects/_specific_presentation.html.erb
git commit -m "feat(design): reskin _specific_presentation to Radical — teal hero + madras"
```

---

## Task 7: Reskin `_unanswered_questions.html.erb`

**Files:**
- Replace: `app/views/student/subjects/_unanswered_questions.html.erb`

Existing locals (unchanged): `unanswered_questions`, `subject`, `session_record`, `access_code`.

- [ ] **Step 1: Replace the partial**

```erb
<%= render "student/subjects/stripes" %>
<%= render "student/subjects/subject_header",
      back_path: student_subject_path(access_code: access_code, id: subject.id),
      suptitle: subject.exam_type&.upcase,
      title: subject.title %>

<%# Yellow alert banner %>
<div class="mx-4 mt-2 px-[18px] py-4 rounded-[16px] bg-rad-paper border-2 border-rad-yellow relative overflow-hidden">
  <span class="absolute left-0 top-0 bottom-0 w-[5px] bg-rad-yellow"></span>
  <div class="flex items-start gap-2.5">
    <div class="w-[34px] h-[34px] rounded-full bg-rad-yellow flex items-center justify-center flex-shrink-0">
      <span class="font-serif text-base text-rad-ink font-bold">!</span>
    </div>
    <div>
      <div class="text-[14px] font-bold text-rad-text mb-1">Toutes les parties sont terminées</div>
      <p class="text-[13px] text-rad-muted leading-relaxed m-0">
        Il reste <strong class="text-rad-text"><%= unanswered_questions.size %> question<%= unanswered_questions.size > 1 ? "s" : "" %></strong>
        (<%= unanswered_questions.sum(:points) %> pts). Veux-tu les traiter avant de valider ?
      </p>
    </div>
  </div>
</div>

<%# Skipped questions list %>
<div class="px-4 mt-5">
  <div class="text-[10.5px] tracking-[0.16em] uppercase text-rad-muted font-bold mb-2.5">Questions sautées</div>
  <div class="flex flex-col gap-2">
    <% unanswered_questions.each do |question| %>
      <div class="px-[18px] py-3.5 rounded-[16px] bg-rad-paper border border-rad-rule flex items-start gap-3">
        <div class="w-11 h-11 rounded-[12px] bg-rad-yellow flex items-center justify-center flex-shrink-0">
          <span class="font-serif text-sm text-rad-ink"><%= question.number %></span>
        </div>
        <div class="flex-1 min-w-0">
          <div class="text-[11px] text-rad-muted mb-0.5">Partie <%= question.part.number %></div>
          <p class="font-serif text-[14px] leading-snug text-rad-text m-0 mb-2"><%= truncate(question.label, length: 120) %></p>
          <span class="text-[11px] font-bold px-2 py-1 rounded-[6px] bg-rad-raise border border-rad-rule text-rad-muted">
            <%= question.points %> pts
          </span>
        </div>
        <%= link_to "Répondre",
            student_question_path(access_code: access_code, subject_id: subject.id, id: question.id, from: "review"),
            class: "flex-shrink-0 px-3 py-2 rounded-full border border-rad-text bg-transparent text-rad-text text-xs font-bold no-underline" %>
      </div>
    <% end %>
  </div>
</div>

<%# Sticky bar %>
<div class="sticky bottom-0 px-4 pb-8 pt-3 bg-rad-bg border-t border-rad-rule mt-4 flex gap-2.5">
  <%= button_to "Ignorer et terminer",
      student_subject_completion_path(access_code: access_code, subject_id: subject.id),
      method: :post,
      class: "flex-1 py-3.5 rounded-[14px] border-[1.5px] border-rad-text bg-transparent text-rad-text text-[13px] font-bold cursor-pointer" %>
  <%= link_to student_question_path(access_code: access_code, subject_id: subject.id, id: unanswered_questions.first.id, from: "review"),
      class: "flex-[1.5] py-3.5 rounded-[14px] bg-rad-red text-rad-cream text-[13px] font-bold text-center no-underline" do %>
    Répondre aux <%= unanswered_questions.size %> questions →
  <% end %>
</div>
```

- [ ] **Step 2: Commit the partial only**

All spec selector updates are batched in Task 10.

```bash
git add app/views/student/subjects/_unanswered_questions.html.erb
git commit -m "feat(design): reskin _unanswered_questions to Radical — yellow alert + answer links"
```

---

## Task 8: Reskin `_completion.html.erb`

**Files:**
- Replace: `app/views/student/subjects/_completion.html.erb`

Locals: `access_code`, `subject`, `session_record`. These are always passed from `show.html.erb` (Task 9 passes all three). No `local_assigns` guards needed.

- [ ] **Step 1: Replace the partial**

```erb
<%= render "student/subjects/stripes" %>

<%# Confetti (respects prefers-reduced-motion) %>
<%= render(ConfettiComponent.new) %>

<div class="flex flex-col min-h-[calc(100vh-6px)]">
  <div class="flex-1 flex flex-col items-center px-6 pt-8 text-center">
    <%# Green concentric circle %>
    <div class="relative w-24 h-24 mb-6">
      <div class="absolute inset-0 rounded-full bg-rad-green opacity-15"></div>
      <div class="absolute inset-2 rounded-full bg-rad-green opacity-20"></div>
      <div class="absolute inset-0 flex items-center justify-center">
        <span class="font-serif text-[44px] text-rad-green leading-none">✓</span>
      </div>
    </div>

    <span class="font-serif text-[30px] leading-snug block mb-2.5">
      Sujet terminé<span class="text-rad-green">.</span>
    </span>
    <p class="text-[15px] text-rad-muted leading-relaxed mb-8 max-w-[280px]">
      Tu as répondu à toutes les questions.
    </p>

    <%# Stats %>
    <%
      all_qs    = subject.parts.joins(:questions).merge(Question.kept).count
      all_pts   = subject.parts.joins(:questions).merge(Question.kept).sum("questions.points")
      all_parts = subject.parts.count
    %>
    <div class="flex rounded-[18px] overflow-hidden border border-rad-rule bg-rad-paper w-full">
      <% [[all_qs, "Questions"], [all_pts, "Points"], [all_parts, "Parties"]].each_with_index do |(val, lbl), i| %>
        <div class="flex-1 py-[18px] px-3 text-center <%= i < 2 ? 'border-r border-rad-rule' : '' %>">
          <span class="font-serif text-[28px] text-rad-green leading-none block mb-1"><%= val %></span>
          <span class="text-[11px] text-rad-muted uppercase tracking-[0.1em] font-semibold"><%= lbl %></span>
        </div>
      <% end %>
    </div>
  </div>

  <%# Exit buttons %>
  <div class="px-4 pb-8 pt-6 flex flex-col gap-2.5">
    <%= link_to student_subject_path(access_code: access_code, id: subject.id),
        class: "w-full py-3.5 rounded-[14px] bg-rad-green text-rad-cream text-[14px] font-bold text-center no-underline block" do %>
      Voir les corrections →
    <% end %>
    <%= link_to student_root_path(access_code: access_code),
        class: "w-full py-3.5 rounded-[14px] border-[1.5px] border-rad-rule bg-transparent text-rad-text text-[13px] font-bold text-center no-underline block" do %>
      Retour aux sujets
    <% end %>
  </div>
</div>
```

- [ ] **Step 2: Commit the partial only**

All spec selector updates are batched in Task 10.

```bash
git add app/views/student/subjects/_completion.html.erb
git commit -m "feat(design): reskin _completion to Radical — green circle, stats, exit buttons"
```

---

## Task 9: Reskin `show.html.erb` — else-block (parts list) and relecture mode

**Files:**
- Modify: `app/views/student/subjects/show.html.erb`

This is the main orchestrator. The conditional structure (`if requires_scope_selection / elsif show_completion / elsif unanswered / elsif show_specific_presentation / else`) is preserved. Changes:

1. Wrap the entire view in `bg-rad-bg min-h-screen` (remove old `max-w-3xl mx-auto px-4 py-8` wrapper).
2. The `else` block (parts list) gets: stripes + subject_header, global progress bar, tutor banner, section headers with coloured pills, `_part_row` cards, sticky CTA.
3. Relecture mode banner is replaced with the Radical teal badge style.
4. Pass `subject: @subject, session_record: @session_record` to `_completion`.
5. Remove the "Mise en situation" block (migrates to PR3 questions/show).

- [ ] **Step 1: Replace `show.html.erb`**

```erb
<div class="bg-rad-bg min-h-screen text-rad-text">
  <% if @session_record.requires_scope_selection? && !@session_record.scope_selected? %>
    <%# === SCOPE SELECTION === %>
    <%= render "student/subjects/scope_selection",
        subject: @subject,
        session_record: @session_record,
        access_code: params[:access_code] %>

  <% elsif @show_completion %>
    <%# === COMPLETION === %>
    <%= render "student/subjects/completion",
        access_code: params[:access_code],
        subject: @subject,
        session_record: @session_record %>

  <% elsif @unanswered_questions %>
    <%# === UNANSWERED QUESTIONS === %>
    <%= render "student/subjects/unanswered_questions",
        unanswered_questions: @unanswered_questions,
        subject: @subject,
        session_record: @session_record,
        access_code: params[:access_code] %>

  <% elsif @show_specific_presentation %>
    <%# === SPECIFIC PRESENTATION === %>
    <%= render "student/subjects/specific_presentation",
        subject: @subject,
        first_question: @first_specific_question,
        session_record: @session_record,
        access_code: params[:access_code] %>

  <% else %>
    <%# === PARTS LIST (standard flow + relecture) === %>
    <%= render "student/subjects/stripes" %>
    <%= render "student/subjects/subject_header",
          back_path: student_root_path(access_code: params[:access_code]),
          suptitle: [@subject.exam_type&.upcase, @subject.specialty&.upcase].compact.join(" · "),
          title: @subject.title %>

    <%# Global progress bar %>
    <%
      all_questions = @parts.flat_map { |p| p.questions.kept.to_a }
      total_q  = all_questions.size
      answered_q = all_questions.count { |q| @session_record.answered?(q.id) }
    %>
    <div class="px-5 pb-4">
      <div class="flex justify-between mb-1.5">
        <span class="text-[11px] font-bold tracking-[0.1em] uppercase text-rad-muted">Progression</span>
        <span class="text-[11px] font-semibold text-rad-muted"><%= answered_q %> / <%= total_q %></span>
      </div>
      <div class="h-[5px] rounded-full bg-rad-rule overflow-hidden">
        <div class="h-full bg-rad-teal rounded-full transition-all"
             style="width: <%= total_q > 0 ? (answered_q * 100 / total_q) : 0 %>%"></div>
      </div>
    </div>

    <%# Tutor banner (autonomous students only) %>
    <% if @session_record.autonomous? %>
      <%= render "student/tutor/tutor_banner",
                 tutor_status: @tutor_status,
                 access_code: params[:access_code] %>
    <% end %>

    <%# Relecture mode badge %>
    <% if @relecture_mode %>
      <div class="mx-5 mb-4 flex items-center gap-2">
        <span class="text-[10.5px] font-bold tracking-[0.14em] uppercase px-2.5 py-1 rounded-full
                     bg-rad-teal/10 text-rad-teal border border-rad-teal/30">
          Mode relecture
        </span>
        <span class="text-xs text-rad-muted">Sujet complété</span>
      </div>

      <div class="mx-4 mb-4 px-[18px] py-3.5 rounded-[16px] bg-rad-paper border border-rad-rule flex items-center gap-3.5">
        <div class="w-11 h-11 rounded-[12px] bg-rad-green flex items-center justify-center flex-shrink-0">
          <span class="text-rad-cream text-xl">✓</span>
        </div>
        <div class="flex-1">
          <div class="text-[13px] font-bold text-rad-text mb-0.5">
            <%= @session_record.answered_count %> / <%= all_questions.size %> questions répondues
          </div>
          <div class="text-xs text-rad-muted">Toutes les parties terminées</div>
        </div>
      </div>
    <% end %>

    <%# Parts grouped by section_type %>
    <%
      common_parts_list   = common_parts(@parts)
      specific_parts_list = specific_parts(@parts)
      show_section_headers = common_parts_list.any? && specific_parts_list.any?
    %>
    <div class="px-4">
      <% if show_section_headers && common_parts_list.any? %>
        <div class="flex items-center gap-2 mb-2">
          <span class="w-[3px] h-3 bg-rad-teal rounded-sm"></span>
          <span class="text-[10.5px] tracking-[0.14em] uppercase text-rad-muted font-bold">PARTIE COMMUNE · TC</span>
        </div>
      <% end %>
      <% common_parts_list.each do |part| %>
        <%= render "student/subjects/part_row", part: part, session_record: @session_record %>
      <% end %>

      <% if show_section_headers && specific_parts_list.any? %>
        <div class="flex items-center gap-2 mb-2 mt-4">
          <span class="w-[3px] h-3 bg-rad-yellow rounded-sm"></span>
          <span class="text-[10.5px] tracking-[0.14em] uppercase text-rad-muted font-bold">PARTIE SPÉCIFIQUE · <%= @subject.specialty&.upcase %></span>
        </div>
      <% end %>
      <% specific_parts_list.each do |part| %>
        <%= render "student/subjects/part_row", part: part, session_record: @session_record %>
      <% end %>
    </div>

    <div class="h-20"></div>

    <%# Sticky CTA %>
    <% if @relecture_mode %>
      <div class="sticky bottom-0 px-4 pb-8 pt-3 bg-rad-bg border-t border-rad-rule flex gap-2.5">
        <%= link_to student_root_path(access_code: params[:access_code]),
            class: "flex-1 py-3.5 rounded-[14px] border-[1.5px] border-rad-text bg-transparent text-rad-text text-[13px] font-bold text-center no-underline" do %>
          Retour aux sujets
        <% end %>
        <%= link_to student_question_path(access_code: params[:access_code], subject_id: @subject.id, id: @first_question.id),
            class: "flex-[1.5] py-3.5 rounded-[14px] bg-rad-raise text-rad-text text-[13px] font-bold text-center no-underline" do %>
          Reprendre la lecture →
        <% end %>
      </div>
    <% else %>
      <%
        active_part = @parts.find { |p| !@session_record.part_completed?(p.id) }
      %>
      <% if active_part %>
        <div class="sticky bottom-0 px-4 pb-8 pt-3 bg-rad-bg border-t border-rad-rule flex gap-2.5">
          <%
            first_q = active_part.questions.kept.order(:position).first
            needs_specific_presentation = active_part.section_type == "specific" &&
              @subject.specific_presentation.present? &&
              !@session_record.specific_presentation_seen?
            cta_path = if needs_specific_presentation
              student_subject_path(access_code: params[:access_code], id: @subject.id, start: true)
            elsif first_q
              student_question_path(access_code: params[:access_code], subject_id: @subject.id, id: first_q.id)
            end
          %>
          <% if cta_path %>
            <%= link_to cta_path,
                class: "flex-[1.5] py-3.5 rounded-[14px] bg-rad-red text-rad-cream text-[13px] font-bold text-center no-underline" do %>
              Continuer la partie <%= active_part.number %> →
            <% end %>
          <% end %>
        </div>
      <% end %>
    <% end %>
  <% end %>
</div>
```

- [ ] **Step 2: Commit the view only**

All spec selector updates are batched in Task 10.

```bash
git add app/views/student/subjects/show.html.erb
git commit -m "feat(design): reskin subjects#show else-block to Radical — progress bar, parts list, relecture"
```

---

## Task 10: Update spec selectors + add new Radical UI specs

**Files:**
- Modify: `spec/features/student/subject_workflow_spec.rb`

All spec selector changes from the partial reskins are batched here. Make each change, then run the full spec suite once at the end.

- [ ] **Step 1: Update `select_full_scope` helper**

```ruby
# Was:
def select_full_scope
  visit student_subject_path(access_code: classroom.access_code, id: subject_record.id)
  click_button "Sujet complet"
end

# Replace with:
def select_full_scope
  visit student_subject_path(access_code: classroom.access_code, id: subject_record.id)
  # "full" is pre-selected by default — just submit
  click_button "Commencer →"
end
```

- [ ] **Step 2: Update `common_only` scope scenario — add `js: true`**

Find the scenario `"single scope (common_only) shows flat list without section headers"` and update it:

```ruby
scenario "single scope (common_only) shows flat list without section headers", js: true do
  visit student_subject_path(access_code: classroom.access_code, id: subject_record.id)
  find("[data-value='common_only']").click
  click_button "Commencer →"
  # ... rest of scenario assertions unchanged
end
```

- [ ] **Step 3: Replace `click_link "Commencer"` with new CTA**

Every `click_link "Commencer"` that follows `select_full_scope` in the spec must become `click_link "Continuer la partie 1 →"` (the active part on first visit is always part 1). Search and replace:

```ruby
# Replace all occurrences of:
click_link "Commencer"
# With:
click_link "Continuer la partie 1 →"
```

For the specific presentation "Commencer →" link (US3 scenarios), it is unchanged — the new partial already uses `"Commencer →"` for that button.

- [ ] **Step 4: Update "Terminé" badge selector**

```ruby
# Replace:
expect(page).to have_content("Terminé")
# With:
expect(find("[data-part-id='#{common_part.id}']")["data-part-completed"]).to eq("true")
```

- [ ] **Step 5: Update unanswered questions selectors**

```ruby
# Replace all occurrences:
# have_content("Questions non repondues")
#   → have_content("Questions sautées")
# have_link("Revenir a cette question", minimum: 1)
#   → have_link("Répondre", minimum: 1)
# first(:link, "Revenir a cette question").click
#   → first(:link, "Répondre").click
# click_button "Terminer le sujet"
#   → click_button "Ignorer et terminer"
# have_button("Terminer le sujet")
#   → have_button("Ignorer et terminer")
```

- [ ] **Step 6: Update completion page selectors**

```ruby
# Replace all occurrences:
# have_content("Bravo")       → have_content("Sujet terminé")
# not_to have_content("Bravo") → not_to have_content("Sujet terminé")
# have_link("Revenir aux sujets") → have_link("Retour aux sujets")
```

- [ ] **Step 7: Update section header accent selector**

```ruby
# Replace:
# expect(page).to have_content("PARTIE SPECIFIQUE")
# With:
expect(page).to have_content("PARTIE SPÉCIFIQUE")
# Note: "PARTIE COMMUNE" still matches "PARTIE COMMUNE · TC" — no change needed.
```

- [ ] **Step 8: Run full spec suite to confirm all existing scenarios pass**

```bash
bundle exec rspec spec/features/student/subject_workflow_spec.rb --format documentation
```

Expected: all existing examples pass (0 failures).

- [ ] **Step 9: Write new Radical UI specs**

Add at the end of the spec file, before the final `end`:

```ruby
# ---------- Radical UI: visual elements ----------

describe "Radical UI elements" do
  scenario "stripes bar is present on scope selection screen" do
    visit student_subject_path(access_code: classroom.access_code, id: subject_record.id)
    expect(page).to have_css("[aria-hidden='true'].flex.h-1\\.5")
  end

  scenario "scope selector has data-controller attribute" do
    visit student_subject_path(access_code: classroom.access_code, id: subject_record.id)
    expect(page).to have_css("[data-controller='scope-selector']")
  end

  scenario "scope selector radio cards have data-value attributes" do
    visit student_subject_path(access_code: classroom.access_code, id: subject_record.id)
    expect(page).to have_css("[data-value='full']")
    expect(page).to have_css("[data-value='common_only']")
    expect(page).to have_css("[data-value='specific_only']")
  end

  scenario "parts list shows global progress bar after scope selection" do
    select_full_scope
    expect(page).to have_css(".h-\\[5px\\].rounded-full")
  end

  scenario "completion screen shows Sujet terminé heading" do
    select_full_scope
    click_link "Continuer la partie 1 →"
    click_link "Question suivante"
    click_button "Fin de la partie commune"
    click_link "Commencer →"
    click_link "Question suivante"
    click_button "Fin de la partie spécifique"
    click_button "Ignorer et terminer"

    expect(page).to have_content("Sujet terminé")
    expect(page).to have_link("Retour aux sujets")
  end
end
```

- [ ] **Step 10: Run new Radical UI specs**

```bash
bundle exec rspec spec/features/student/subject_workflow_spec.rb -e "Radical UI" --format documentation
```

Expected: all 5 examples pass.

- [ ] **Step 11: Run full spec file**

```bash
bundle exec rspec spec/features/student/subject_workflow_spec.rb --format documentation
```

Expected: all examples pass.

- [ ] **Step 12: Commit**

```bash
git add spec/features/student/subject_workflow_spec.rb
git commit -m "test(design): update selectors + add Radical UI specs for subjects#show"
```

---

## Task 11: Final verification and PR

**Files:** None (verification only)

- [ ] **Step 1: Run the full RSpec suite to check for regressions**

```bash
bundle exec rspec --format progress
```

Expected: 0 failures. Any pre-existing failures must not be new regressions introduced by this branch.

- [ ] **Step 2: Start the dev server and visually verify**

```bash
bin/dev
```

Open `http://localhost:3000` in a browser. Navigate to a student subject page and verify:
- Stripes bar visible at top
- Fonts: Fraunces for headers/numbers, Inter for body
- Cream background (`#fbf7ee`), balisier red CTAs
- Dark mode toggle: teal/cream background swaps correctly
- Scope selector: clicking a card highlights it, "Commencer →" submits
- Parts list: progress bar, accent bars on part rows, "En cours" badge
- Specific presentation: teal hero card with madras pattern

- [ ] **Step 3: Open the PR**

```bash
git push origin 054-subjects-show-radical
gh pr create \
  --title "feat(design): PR2 subjects/show — Radical reskin (6 états)" \
  --body "$(cat <<'EOF'
## Summary
- Reskins all 6 conditional states of `subjects#show` to the Radical design system (cream/balisier/teal palette, Fraunces + Inter)
- Adds 2 new shared partials: `_stripes` (4-colour band) and `_subject_header` (compact mobile header)
- Adds `scope_selector` Stimulus controller (radio cards + deferred form submit)
- No controller changes, no migrations — pure view layer

## Test plan
- [ ] All existing feature specs in `subject_workflow_spec.rb` pass
- [ ] 5 new Radical UI specs pass
- [ ] Visual verification in browser: all 6 states rendered correctly
- [ ] Dark mode: no regression

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```
