# Tutor Chips Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add dynamic context-sensitive chips to Tibo's drawer — rendered server-side from `TutorState#current_phase`, updated via ActionCable at end of each turn, with three dispatch behaviors (send message, PATCH confidence, navigate).

**Architecture:** A `turbo_frame` named `tutor-chips` sits between the messages zone and the input bar in `_drawer.html.erb`. A new `Tutor::ChipsPresenter` service computes chip descriptors from phase/hints_used. `BroadcastMessage` renders the chips partial and sends `chips_html` in the `done` payload. `tutor_chat_controller.js` clears the frame on send, injects HTML on `#onDone`, and dispatches chip clicks by `data-chip-action` attribute.

**Tech Stack:** Rails 8.1, ERB partials, Hotwire/ActionCable, Stimulus, Tailwind CSS (rad-* tokens), RSpec + Capybara

---

## File Map

| File | Status | Responsibility |
|---|---|---|
| `app/services/tutor/chips_presenter.rb` | Create | Phase → chip descriptor array |
| `app/views/student/conversations/_chips.html.erb` | Create | Render chip descriptors as HTML |
| `app/views/student/conversations/_drawer.html.erb` | Modify | Add `tutor-chips` frame + pass `next_question_url` |
| `app/services/tutor/broadcast_message.rb` | Modify | Add `chips_html` to done payload, accept `question`/`access_code` |
| `app/services/tutor/process_message.rb` | Modify | Pass `question` + `access_code` to `BroadcastMessage` |
| `app/views/student/conversations/confidence.turbo_stream.erb` | Modify | Replace `confidence-form-*` frame AND update `tutor-chips` to feedback chips |
| `app/javascript/controllers/tutor_chat_controller.js` | Modify | Clear chips on send, inject on done, dispatch chip clicks |
| `spec/services/tutor/chips_presenter_spec.rb` | Create | Unit tests for presenter |
| `spec/features/student_tutor_full_flow_spec.rb` | Modify | Remove 3 `pending:` annotations (lines 139, 161, 186) |

---

## Task 1: `Tutor::ChipsPresenter` — service pur

**Files:**
- Create: `app/services/tutor/chips_presenter.rb`
- Create: `spec/services/tutor/chips_presenter_spec.rb`

- [ ] **Step 1: Write the failing specs**

```ruby
# spec/services/tutor/chips_presenter_spec.rb
require "rails_helper"

RSpec.describe Tutor::ChipsPresenter do
  def chips(phase:, hints_used: 0)
    described_class.call(phase: phase, hints_used: hints_used)
  end

  describe "idle / no conversation" do
    it "returns empty array" do
      expect(chips(phase: "idle")).to eq([])
    end
  end

  describe "greeting / enonce" do
    %w[greeting enonce].each do |phase|
      context "phase=#{phase}" do
        subject { chips(phase: phase) }
        it "has 2 chips: Reformule + Définis" do
          expect(subject.map { _1[:label] }).to eq(["Reformule la question", "Définis un terme"])
        end
        it "all chips are :send action" do
          expect(subject.map { _1[:action] }).to all(eq(:send))
        end
        it "Reformule uses teal color" do
          expect(subject[0][:color]).to eq(:teal)
        end
        it "Définis uses red color" do
          expect(subject[1][:color]).to eq(:red)
        end
      end
    end
  end

  describe "spotting_type / spotting_data" do
    %w[spotting_type spotting_data].each do |phase|
      context "phase=#{phase}" do
        subject { chips(phase: phase) }
        it "has 2 chips: Donne un exemple + Reformule" do
          expect(subject.map { _1[:label] }).to eq(["Donne un exemple", "Reformule la question"])
        end
        it "Donne un exemple uses yellow color" do
          expect(subject[0][:color]).to eq(:yellow)
        end
      end
    end
  end

  describe "guiding" do
    context "hints_used < 5" do
      subject { chips(phase: "guiding", hints_used: 2) }
      it "has 3 chips: Un indice + Reformule + Définis" do
        expect(subject.map { _1[:label] }).to eq(["Un indice", "Reformule", "Définis"])
      end
      it "Un indice is not disabled" do
        expect(subject[0][:disabled]).to be_falsey
      end
      it "Un indice uses yellow color" do
        expect(subject[0][:color]).to eq(:yellow)
      end
    end

    context "hints_used = 5 (MAX_HINTS)" do
      subject { chips(phase: "guiding", hints_used: 5) }
      it "has 3 chips including disabled Un indice last" do
        expect(subject.map { _1[:label] }).to eq(["Reformule", "Définis", "Un indice"])
      end
      it "Un indice is disabled" do
        hint_chip = subject.find { _1[:label] == "Un indice" }
        expect(hint_chip[:disabled]).to be_truthy
      end
    end
  end

  describe "validating" do
    subject { chips(phase: "validating") }
    it "has 5 confidence chips" do
      expect(subject.size).to eq(5)
    end
    it "all chips are :confidence action" do
      expect(subject.map { _1[:action] }).to all(eq(:confidence))
    end
    it "levels are 1..5" do
      expect(subject.map { _1[:level] }).to eq([1, 2, 3, 4, 5])
    end
    it "labels include emojis" do
      expect(subject[0][:label]).to include("😰")
      expect(subject[4][:label]).to include("💪")
    end
  end

  describe "feedback / ended" do
    %w[feedback ended].each do |phase|
      context "phase=#{phase}" do
        subject { chips(phase: phase) }
        it "has Explique la correction chip (send)" do
          chip = subject.find { _1[:label] == "Explique la correction" }
          expect(chip).to be_present
          expect(chip[:action]).to eq(:send)
        end
        it "has Question suivante chip (navigate)" do
          chip = subject.find { _1[:action] == :navigate }
          expect(chip).to be_present
          expect(chip[:label]).to include("suivante")
        end
      end
    end
  end
end
```

- [ ] **Step 2: Run to confirm failure**

```bash
bundle exec rspec spec/services/tutor/chips_presenter_spec.rb --no-color 2>&1 | tail -10
```
Expected: multiple failures — `uninitialized constant Tutor::ChipsPresenter`

- [ ] **Step 3: Implement `Tutor::ChipsPresenter`**

```ruby
# app/services/tutor/chips_presenter.rb
module Tutor
  class ChipsPresenter
    CONFIDENCE_LABELS = {
      1 => "😰 Pas du tout sûr",
      2 => "😅 Peu sûr",
      3 => "🙂 Moyennement sûr",
      4 => "😊 Assez sûr",
      5 => "💪 Très sûr"
    }.freeze

    CONFIDENCE_COLORS = { 1 => :red, 2 => :yellow, 3 => :teal, 4 => :teal, 5 => :teal }.freeze

    def self.call(phase:, hints_used: 0)
      new(phase: phase, hints_used: hints_used).call
    end

    def initialize(phase:, hints_used: 0)
      @phase      = phase.to_s
      @hints_used = hints_used.to_i
    end

    def call
      case @phase
      when "greeting", "enonce"         then greeting_chips
      when "spotting_type", "spotting_data" then spotting_chips
      when "guiding"                    then guiding_chips
      when "validating"                 then validating_chips
      when "feedback", "ended"          then feedback_chips
      else []
      end
    end

    private

    def greeting_chips
      [
        send_chip("Reformule la question", "Peux-tu reformuler la question ?", :teal),
        send_chip("Définis un terme",      "Peux-tu définir un terme clé ?",    :red)
      ]
    end

    def spotting_chips
      [
        send_chip("Donne un exemple",     "Donne-moi un exemple.",             :yellow),
        send_chip("Reformule la question","Peux-tu reformuler la question ?",   :teal)
      ]
    end

    def guiding_chips
      hint_disabled = @hints_used >= Tutor::ApplyToolCalls::MAX_HINTS
      hint = send_chip("Un indice", "Donne-moi un indice.", :yellow, disabled: hint_disabled)
      reformule = send_chip("Reformule", "Peux-tu reformuler la question ?", :teal)
      definis   = send_chip("Définis",   "Peux-tu définir un terme clé ?",   :red)

      if hint_disabled
        [reformule, definis, hint]
      else
        [hint, reformule, definis]
      end
    end

    def validating_chips
      (1..5).map do |level|
        {
          label:   CONFIDENCE_LABELS[level],
          action:  :confidence,
          level:   level,
          color:   CONFIDENCE_COLORS[level],
          stacked: true
        }
      end
    end

    def feedback_chips
      [
        send_chip("Explique la correction", "Explique-moi la correction.", :teal),
        { label: "Question suivante →", action: :navigate, color: :red }
      ]
    end

    def send_chip(label, text, color, disabled: false)
      { label: label, action: :send, text: text, color: color, disabled: disabled }
    end
  end
end
```

- [ ] **Step 4: Run specs**

```bash
bundle exec rspec spec/services/tutor/chips_presenter_spec.rb --no-color 2>&1 | tail -5
```
Expected: all green

- [ ] **Step 5: Commit**

```bash
git add app/services/tutor/chips_presenter.rb spec/services/tutor/chips_presenter_spec.rb
git commit -m "feat(tutor): add ChipsPresenter — phase → chip descriptor array"
```

---

## Task 2: Partial `_chips.html.erb`

**Files:**
- Create: `app/views/student/conversations/_chips.html.erb`

- [ ] **Step 1: Create the partial**

```erb
<%#
  Locals:
    conversation      (Conversation | nil)
    question          (Question)
    access_code       (String)
    next_question_url (String | nil) — URL de la question suivante, nil si dernière
%>
<% return unless conversation %>

<%
  ts         = conversation.tutor_state
  qid        = ts.current_question_id.to_s
  hints_used = ts.question_states[qid]&.hints_used.to_i
  chips      = Tutor::ChipsPresenter.call(phase: ts.current_phase, hints_used: hints_used)
%>

<% if chips.any? %>
  <div id="tutor-chips-inner"
       class="px-3 pb-2 flex <%= chips.first[:stacked] ? 'flex-col' : 'flex-row flex-wrap' %> gap-1.5">
    <% chips.each do |chip| %>
      <% color_class = { teal: "border-rad-teal", red: "border-rad-red", yellow: "border-rad-yellow" }[chip[:color]] || "border-rad-rule" %>
      <% base_classes = "text-[11.5px] font-semibold bg-rad-paper border border-rad-rule #{color_class} text-rad-text leading-none cursor-pointer transition-opacity" %>
      <% shape_classes = chip[:stacked] ? "rounded-lg px-3 py-[7px] border-l-[3px]" : "rounded-full px-3 py-[7px] border-l-[3px]" %>
      <% disabled_classes = chip[:disabled] ? "opacity-40 cursor-not-allowed pointer-events-none line-through" : "hover:opacity-80" %>

      <% if chip[:action] == :send %>
        <button type="button"
                data-chip-action="send"
                data-chip-text="<%= chip[:text] %>"
                class="<%= base_classes %> <%= shape_classes %> <%= disabled_classes %>"
                <%= chip[:disabled] ? "disabled aria-disabled='true'" : "" %>>
          <%= chip[:label] %>
        </button>

      <% elsif chip[:action] == :confidence %>
        <button type="button"
                data-chip-action="confidence"
                data-chip-level="<%= chip[:level] %>"
                data-confidence-url="<%= confidence_student_conversation_path(access_code: access_code, id: conversation.id) %>"
                class="<%= base_classes %> <%= shape_classes %> <%= disabled_classes %>">
          <%= chip[:label] %>
        </button>

      <% elsif chip[:action] == :navigate && next_question_url.present? %>
        <%= link_to chip[:label],
              next_question_url,
              class: "#{base_classes} #{shape_classes} #{disabled_classes} no-underline" %>
      <% end %>
    <% end %>
  </div>
<% end %>
```

- [ ] **Step 2: Smoke-check rendering via Rails console (no browser needed)**

```bash
bundle exec rails runner '
  q = Question.first
  conv = Conversation.last
  puts ActionController::Base.render(
    partial: "student/conversations/chips",
    locals: { conversation: conv, question: q, access_code: "test", next_question_url: nil }
  ).length > 0 ? "OK" : "EMPTY"
' 2>&1 | tail -5
```
Expected: `OK` (or a non-zero length)

- [ ] **Step 3: Commit**

```bash
git add app/views/student/conversations/_chips.html.erb
git commit -m "feat(tutor): add _chips partial — renders chip descriptors from ChipsPresenter"
```

---

## Task 3: Intégrer le frame `tutor-chips` dans `_drawer.html.erb`

**Files:**
- Modify: `app/views/student/conversations/_drawer.html.erb`

Le frame est inséré entre la zone messages (`#tutor-chat-messages`) et le streaming placeholder. Il reçoit le partial déjà rendu au chargement. Le `next_question_url` est calculé ici directement (le drawer est rendu dans `questions#show` via Turbo Stream, qui a accès aux variables d'instance).

- [ ] **Step 1: Modifier `_drawer.html.erb`**

Après la div `#tutor-chat-messages` (ligne ~80), avant le streaming placeholder, ajouter :

```erb
  <%# Chips contextuelles — mises à jour par ActionCable en fin de tour %>
  <turbo-frame id="tutor-chips" class="shrink-0">
    <%= render "student/conversations/chips",
          conversation:      conversation,
          question:          question,
          access_code:       access_code,
          next_question_url: local_assigns[:next_question_url] %>
  </turbo-frame>
```

Le fichier complet entre `</div>` (fin messages) et le streaming placeholder devient :

```erb
  </div>

  <%# Chips contextuelles — mises à jour par ActionCable en fin de tour %>
  <turbo-frame id="tutor-chips" class="shrink-0">
    <%= render "student/conversations/chips",
          conversation:      conversation,
          question:          question,
          access_code:       access_code,
          next_question_url: local_assigns[:next_question_url] %>
  </turbo-frame>

  <%# Streaming placeholder %>
  <div data-tutor-chat-target="streamingPlaceholder"
```

- [ ] **Step 2: Passer `next_question_url` là où le drawer est rendu**

Dans `app/views/student/questions/show.html.erb`, trouver le render du drawer et ajouter `next_question_url: next_href` :

```erb
<%= render "student/conversations/drawer",
      conversation:      @conversation,
      question:          @question,
      access_code:       params[:access_code],
      next_question_url: next_href %>
```

Dans `app/controllers/student/conversations_controller.rb`, action `create`, le `turbo_stream.replace` du drawer — ajouter `next_question_url: nil` (pas de contexte de navigation disponible depuis ce controller) :

```ruby
streams << turbo_stream.replace(
  "tutor-chat-drawer",
  partial: "student/conversations/drawer",
  locals:  {
    conversation:      @conversation,
    question:          @question_for_drawer || @subject.questions.first,
    access_code:       params[:access_code],
    next_question_url: nil
  }
)
```

- [ ] **Step 3: Vérifier qu'aucun autre endroit ne rend le drawer**

```bash
grep -rn "student/conversations/drawer" app/ --include="*.erb" --include="*.rb"
```
Corriger tous les appels trouvés en ajoutant `next_question_url: nil` si le contexte ne permet pas de le calculer.

- [ ] **Step 4: Commit**

```bash
git add app/views/student/conversations/_drawer.html.erb \
        app/views/student/questions/show.html.erb \
        app/controllers/student/conversations_controller.rb
git commit -m "feat(tutor): add tutor-chips frame to drawer, wired to initial TutorState"
```

---

## Task 4: `BroadcastMessage` — ajouter `chips_html` au payload `done`

**Files:**
- Modify: `app/services/tutor/broadcast_message.rb`
- Modify: `app/services/tutor/process_message.rb`

- [ ] **Step 1: Modifier `BroadcastMessage`**

```ruby
# app/services/tutor/broadcast_message.rb
module Tutor
  class BroadcastMessage
    def self.call(conversation:, message:, question:, access_code:)
      new(conversation: conversation, message: message, question: question, access_code: access_code).call
    end

    def initialize(conversation:, message:, question:, access_code:)
      @conversation = conversation
      @message      = message
      @question     = question
      @access_code  = access_code
    end

    def call
      ActionCable.server.broadcast(
        "conversation_#{@conversation.id}",
        {
          type: "done",
          message: {
            id:                    @message.id,
            role:                  @message.role,
            content:               @message.content,
            streaming_finished:    @message.streaming_finished_at.present?,
            streaming_finished_at: @message.streaming_finished_at&.iso8601
          },
          chips_html: render_chips_html
        }
      )
      Result.ok
    end

    private

    def render_chips_html
      ApplicationController.renderer.render(
        partial: "student/conversations/chips",
        locals:  {
          conversation:      @conversation,
          question:          @question,
          access_code:       @access_code,
          next_question_url: nil
        }
      )
    rescue => e
      Rails.logger.error("[BroadcastMessage] chips render failed: #{e.message}")
      ""
    end
  end
end
```

- [ ] **Step 2: Modifier `ProcessMessage` pour passer `question` et `access_code`**

Dans `app/services/tutor/process_message.rb`, la signature du constructeur :

```ruby
def self.call(conversation:, student_input:, question:, access_code:)
  new(conversation: conversation, student_input: student_input, question: question, access_code: access_code).call
end

def initialize(conversation:, student_input:, question:, access_code:)
  @conversation  = conversation
  @student_input = student_input
  @question      = question
  @access_code   = access_code
end
```

Et l'appel à `BroadcastMessage` en fin de `call` :

```ruby
BroadcastMessage.call(
  conversation: @conversation,
  message:      assistant_msg,
  question:     @question,
  access_code:  @access_code
)
```

- [ ] **Step 3: Mettre à jour l'appelant de `ProcessMessage`**

```bash
grep -rn "ProcessMessage.call\|ProcessMessage\.call" app/ --include="*.rb"
```

Trouver le controller ou job qui appelle `Tutor::ProcessMessage.call` et ajouter `access_code: params[:access_code]` (ou l'équivalent disponible dans ce contexte).

- [ ] **Step 4: Chercher d'autres appelants de `BroadcastMessage` à mettre à jour**

```bash
grep -rn "BroadcastMessage.call\|BroadcastMessage\.call" app/ --include="*.rb"
```

Chaque appel doit recevoir `question:` et `access_code:`. Si un contexte ne dispose pas de la question, passer `question: nil` et gérer dans `render_chips_html` :

```ruby
def render_chips_html
  return "" unless @question && @access_code
  # ...
end
```

- [ ] **Step 5: Vérifier les specs request existantes**

```bash
bundle exec rspec spec/requests/student/conversations_spec.rb --no-color 2>&1 | tail -10
```
Expected: all green (ajuster les doubles/stubs si nécessaire)

- [ ] **Step 6: Commit**

```bash
git add app/services/tutor/broadcast_message.rb app/services/tutor/process_message.rb
git commit -m "feat(tutor): BroadcastMessage sends chips_html in done payload"
```

---

## Task 5: `tutor_chat_controller.js` — clear + inject + dispatch

**Files:**
- Modify: `app/javascript/controllers/tutor_chat_controller.js`

- [ ] **Step 1: Ajouter la target `chips`**

Dans les `static targets`, ajouter `"chips"` :

```js
static targets = ["messages", "input", "sendButton", "streamingPlaceholder", "chips"]
```

Et dans `_drawer.html.erb`, ajouter `data-tutor-chat-target="chips"` sur le `<turbo-frame id="tutor-chips">` :

```erb
<turbo-frame id="tutor-chips" data-tutor-chat-target="chips" class="shrink-0">
```

- [ ] **Step 2: Vider les chips au début du stream**

Dans `send()`, après `this.#setStreaming(true)`, ajouter :

```js
if (this.hasChipsTarget) this.chipsTarget.innerHTML = ""
```

- [ ] **Step 3: Injecter les chips à la fin du stream**

Dans `#onDone(message)`, après `this.#setStreaming(false)`, ajouter :

```js
if (data.chips_html && this.hasChipsTarget) {
  this.chipsTarget.innerHTML = data.chips_html
}
```

Mais `#onDone` reçoit `message` (pas `data`). Modifier la signature pour passer `data` complet :

```js
// Dans #handleReceived :
case "done":
  this.#onDone(data)
  break

// Réécrire #onDone :
#onDone(data) {
  const message = data.message
  this.streamingPlaceholderTarget.textContent = ""
  this.streamingPlaceholderTarget.classList.add("hidden")
  if (message && message.content) {
    const div = document.createElement("div")
    div.classList.add(
      "self-start",
      "bg-rad-paper", "border", "border-rad-rule",
      "text-rad-text",
      "px-3", "py-2",
      "rounded-2xl", "rounded-tl-sm",
      "max-w-[86%]", "text-sm", "leading-relaxed", "break-words"
    )
    div.dataset.messageId   = message.id
    div.dataset.messageRole = "assistant"
    div.textContent = message.content
    this.messagesTarget.appendChild(div)
  }
  if (data.chips_html && this.hasChipsTarget) {
    this.chipsTarget.innerHTML = data.chips_html
  }
  this.#setStreaming(false)
  this.#scrollToBottom()
}
```

- [ ] **Step 4: Dispatcher les clics chips**

Ajouter une action dans le `data-controller` div du drawer :

Dans `_drawer.html.erb`, sur l'élément root du controller `tutor-chat` (la div `#tutor-chat-drawer`), ajouter :

```erb
data-action="click->tutor-chat#handleChipClick"
```

Ajouter la méthode dans le controller :

```js
handleChipClick(event) {
  const button = event.target.closest("[data-chip-action]")
  if (!button) return

  const action = button.dataset.chipAction

  if (action === "send") {
    const text = button.dataset.chipText
    if (!text || this.isStreaming) return
    this.inputTarget.value = text
    this.send()

  } else if (action === "confidence") {
    const level = parseInt(button.dataset.chipLevel, 10)
    const url   = button.dataset.confidenceUrl
    if (!level || !url || this.isStreaming) return
    this.#submitConfidence(level, url, button.closest("[id^='tutor-chips']") || button.parentElement)
  }
  // navigate: handled natively by <a href>
}

async #submitConfidence(level, url, chipsContainer) {
  const buttons = chipsContainer.querySelectorAll("[data-chip-action='confidence']")
  buttons.forEach(b => { b.disabled = true; b.classList.add("opacity-50", "cursor-not-allowed") })

  try {
    const response = await fetch(url, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": this.#csrfToken(),
        "Accept": "text/vnd.turbo-stream.html"
      },
      body: JSON.stringify({ level })
    })

    if (response.ok) {
      const html = await response.text()
      Turbo.renderStreamMessage(html)
    } else {
      buttons.forEach(b => { b.disabled = false; b.classList.remove("opacity-50", "cursor-not-allowed") })
    }
  } catch {
    buttons.forEach(b => { b.disabled = false; b.classList.remove("opacity-50", "cursor-not-allowed") })
  }
}
```

- [ ] **Step 5: Désactiver l'input quand phase = validating**

Dans `_chips.html.erb`, ajouter un `data-validating` sur le wrapper quand la phase est `:validating` :

```erb
<% if ts.current_phase == "validating" %>
  <div data-tutor-chat-validating="true" class="hidden"></div>
<% end %>
```

Dans `tutor_chat_controller.js`, dans `#onDone`, après l'injection des chips, détecter et désactiver l'input :

```js
const validatingMarker = this.chipsTarget.querySelector("[data-tutor-chat-validating]")
const isValidating = !!validatingMarker
this.inputTarget.disabled      = isValidating
this.sendButtonTarget.disabled = isValidating
this.inputTarget.placeholder   = isValidating ? "Réponds via les chips ci-dessus…" : "Écris à Tibo…"
```

- [ ] **Step 6: Commit**

```bash
git add app/javascript/controllers/tutor_chat_controller.js \
        app/views/student/conversations/_drawer.html.erb \
        app/views/student/conversations/_chips.html.erb
git commit -m "feat(tutor): wire chip clicks in tutor_chat_controller — send/confidence/navigate"
```

---

## Task 6: Mettre à jour `confidence.turbo_stream.erb` pour injecter les chips feedback

Quand l'élève clique une chip confidence, le PATCH répond avec un Turbo Stream. Actuellement ce stream remplace `confidence-form-#{@question_id}` (l'ancien frame) — il n'existe plus dans le nouveau design. Il doit maintenant :
1. Afficher un message de confirmation dans `tutor-chips`
2. Réinitialiser l'input (enlever disabled)

**Files:**
- Modify: `app/views/student/conversations/confidence.turbo_stream.erb`

Le controller `confidence` a accès à `@conversation` et `@question_id`. On doit aussi exposer `@question` et `@access_code`.

- [ ] **Step 1: Exposer `@question` et `@access_code` dans le controller**

Dans `app/controllers/student/conversations_controller.rb`, action `confidence` :

```ruby
def confidence
  level = params[:level].to_i
  unless (1..5).cover?(level)
    return render json: { error: "Niveau invalide (1-5 requis)." },
                  status: :unprocessable_entity
  end

  q_id = @conversation.tutor_state.current_question_id
  state = @conversation.tutor_state.question_states[q_id.to_s] if q_id
  unless state
    return render json: { error: "Question courante introuvable." },
                  status: :unprocessable_entity
  end

  updated_state = state.with(last_confidence: level)
  new_ts = @conversation.tutor_state.with(
    question_states: @conversation.tutor_state.question_states.merge(q_id.to_s => updated_state)
  )
  @conversation.update!(tutor_state: new_ts)
  @conversation.give_feedback! if @conversation.may_give_feedback?

  @question_id  = q_id
  @question     = Question.find_by(id: q_id)
  @access_code  = params[:access_code]
  render "student/conversations/confidence", formats: [ :turbo_stream ]
end
```

- [ ] **Step 2: Réécrire `confidence.turbo_stream.erb`**

```erb
<%# Remplace le frame tutor-chips par les chips de la phase feedback %>
<%= turbo_stream.replace "tutor-chips" do %>
  <turbo-frame id="tutor-chips" class="shrink-0">
    <% if @question && @access_code %>
      <%= render "student/conversations/chips",
            conversation:      @conversation,
            question:          @question,
            access_code:       @access_code,
            next_question_url: nil %>
    <% end %>
  </turbo-frame>
<% end %>
```

- [ ] **Step 3: Run les specs request conversations**

```bash
bundle exec rspec spec/requests/student/conversations_spec.rb --no-color 2>&1 | tail -10
```
Expected: green

- [ ] **Step 4: Commit**

```bash
git add app/views/student/conversations/confidence.turbo_stream.erb \
        app/controllers/student/conversations_controller.rb
git commit -m "feat(tutor): confidence stream replaces tutor-chips with feedback chips"
```

---

## Task 7: Activer les 3 scenarios `pending:` dans `student_tutor_full_flow_spec.rb`

Maintenant que les chips sont implémentées, les 3 scenarios peuvent être débloqués. Les assertions doivent être adaptées au nouveau DOM (chips dans `#tutor-chips`, pas `[data-controller='confidence-form']`).

**Files:**
- Modify: `spec/features/student_tutor_full_flow_spec.rb`

- [ ] **Step 1: Supprimer les `pending:` et adapter les assertions**

**Scénario ligne 138** — hint counter. Le chip "Un indice" est désormais dans `#tutor-chips` quand phase=guiding. Adapter :

```ruby
scenario "guiding : request_hint(level: 1) affiche le compteur d'indices dans le drawer",
         js: true do
  # ... setup identique ...
  open_drawer_and_send("Je ne comprends pas la formule.")

  # Les chips guiding sont dans #tutor-chips après le stream
  expect(page).to have_css("#tutor-chips [data-chip-action='send']", wait: 10)
  # Le chip "Un indice" est présent (hints_used=1, < MAX_HINTS)
  expect(page).to have_css("#tutor-chips button", text: "Un indice", wait: 5)
end
```

**Scénario ligne 160** — validating injection. Après transition vers `:validating`, les chips confidence doivent apparaître dans `#tutor-chips` :

```ruby
scenario "validation : transition vers :validating injecte le formulaire de confiance dans le drawer",
         js: true do
  # ... setup identique ...
  open_drawer_and_send("J'ai obtenu 56,73 litres.")

  expect(page).to have_css("#tutor-chips [data-chip-action='confidence']", wait: 10)
  expect(page).to have_css("#tutor-chips button", text: /sûr/i, wait: 5)
end
```

**Scénario ligne 185** — confidence click. La conversation est déjà en `:validating`. Au chargement, les chips confidence sont pré-rendues. Cliquer "Moyennement sûr" via le chip :

```ruby
scenario "confiance : cliquer un niveau depuis le drawer enregistre last_confidence et bascule en :feedback",
         js: true do
  conv = create(:conversation,
    student: student, subject: subject_record,
    lifecycle_state: "validating",
    tutor_state: tutor_state_starting_at("validating"))

  visit student_question_path(
    access_code: classroom.access_code,
    subject_id:  subject_record.id,
    id:          question.id
  )

  find("button[aria-label='Ouvrir le tutorat IA']", match: :first).click
  expect(page).to have_css("#tutor-chips [data-chip-action='confidence']", wait: 10)
  find("#tutor-chips button", text: "🙂 Moyennement sûr").click

  expect(conv.reload.lifecycle_state).to eq("feedback")
  q_state = conv.tutor_state.question_states[question.id.to_s]
  expect(q_state.last_confidence).to eq(3)
end
```

- [ ] **Step 2: Run les 3 scenarios isolément**

```bash
bundle exec rspec spec/features/student_tutor_full_flow_spec.rb:138 \
                  spec/features/student_tutor_full_flow_spec.rb:160 \
                  spec/features/student_tutor_full_flow_spec.rb:185 \
                  --no-color 2>&1 | tail -15
```
Expected: 3 examples, 0 failures

- [ ] **Step 3: Run la suite feature complète**

```bash
bundle exec rspec spec/features/ --no-color 2>&1 | tail -10
```
Expected: 0 failures

- [ ] **Step 4: Commit**

```bash
git add spec/features/student_tutor_full_flow_spec.rb
git commit -m "test(tutor): activate 3 pending scenarios — chips now cover hint/validating/confidence"
```

---

## Task 8: Spec feature chips E2E

Ajouter un spec Capybara qui vérifie le comportement des chips dans les phases principales.

**Files:**
- Create: `spec/features/student_tutor_chips_spec.rb`

- [ ] **Step 1: Écrire le spec**

```ruby
# spec/features/student_tutor_chips_spec.rb
require "rails_helper"

RSpec.describe "Tutor chips — comportement contextuel", type: :feature, tutor_streaming: true do
  let(:teacher)   { create(:user) }
  let(:classroom) { create(:classroom, owner: teacher) }
  let(:student) do
    create(:student, classroom: classroom,
      api_key: "sk-test-key", api_provider: :anthropic, use_personal_key: true)
  end
  let(:subject_record) do
    create(:subject, status: :published, owner: teacher,
      specific_presentation: "La société CIME")
  end
  let(:part) { create(:part, :specific, subject: subject_record, number: 1, position: 1) }
  let!(:question) do
    create(:question, part: part, number: "1.1",
      label: "Calculer la consommation.", answer_type: :calcul, points: 2, position: 1)
  end
  let!(:answer) { create(:answer, question: question) }
  let!(:classroom_subject) { create(:classroom_subject, classroom: classroom, subject: subject_record) }
  let!(:autonomous_session) do
    create(:student_session, student: student, subject: subject_record, mode: :autonomous)
  end

  before { login_as_student(student, classroom) }

  def open_drawer
    visit student_question_path(
      access_code: classroom.access_code,
      subject_id:  subject_record.id,
      id:          question.id
    )
    find("button[aria-label='Ouvrir le tutorat IA']", match: :first).click
    expect(page).to have_css("[data-chat-drawer-target='drawer'].translate-x-0", visible: :all, wait: 5)
  end

  def tutor_state_at(phase)
    TutorState.new(
      current_phase: phase, current_question_id: question.id,
      concepts_mastered: [], concepts_to_revise: [], discouragement_level: 0,
      question_states: {}, welcome_sent: true, last_activity_at: nil)
  end

  scenario "phase guiding — chips Un indice, Reformule, Définis visibles", js: true do
    create(:conversation,
      student: student, subject: subject_record,
      lifecycle_state: "active", tutor_state: tutor_state_at("guiding"))

    open_drawer

    expect(page).to have_css("#tutor-chips button", text: "Un indice")
    expect(page).to have_css("#tutor-chips button", text: "Reformule")
    expect(page).to have_css("#tutor-chips button", text: "Définis")
  end

  scenario "phase guiding MAX_HINTS — Un indice grisé", js: true do
    ts = TutorState.new(
      current_phase: "guiding", current_question_id: question.id,
      concepts_mastered: [], concepts_to_revise: [], discouragement_level: 0,
      question_states: { question.id.to_s => QuestionState.new(
        phase: "guiding", step: nil, hints_used: 5,
        last_confidence: nil, error_types: [], completed_at: nil, intro_seen: false
      ) },
      welcome_sent: true, last_activity_at: nil)

    create(:conversation,
      student: student, subject: subject_record,
      lifecycle_state: "active", tutor_state: ts)

    open_drawer

    hint_button = find("#tutor-chips button", text: "Un indice")
    expect(hint_button[:disabled]).to be_truthy
  end

  scenario "phase validating — chips confidence affichées, input désactivé", js: true do
    create(:conversation,
      student: student, subject: subject_record,
      lifecycle_state: "validating", tutor_state: tutor_state_at("validating"))

    open_drawer

    expect(page).to have_css("#tutor-chips [data-chip-action='confidence']", count: 5)
    expect(page).to have_css("#tutor-chips button", text: /Pas du tout sûr/)
    expect(page).to have_css("#tutor-chips button", text: /Très sûr/)
    input = find("[data-tutor-chat-target='input']")
    expect(input[:disabled]).to be_truthy
  end

  scenario "cliquer chip :send envoie le message", js: true do
    FakeRubyLlm.setup_stub(content: "Bonne question !", tool_calls: [])
    create(:conversation,
      student: student, subject: subject_record,
      lifecycle_state: "active", tutor_state: tutor_state_at("guiding"))

    open_drawer

    find("#tutor-chips button", text: "Reformule").click

    expect(page).to have_text("Peux-tu reformuler la question ?", wait: 5)
    expect(page).to have_text("Bonne question !", wait: 10)
  end
end
```

- [ ] **Step 2: Run le spec**

```bash
bundle exec rspec spec/features/student_tutor_chips_spec.rb --no-color 2>&1 | tail -15
```
Expected: 4 examples, 0 failures

- [ ] **Step 3: Run la suite complète**

```bash
bundle exec rspec spec/ --no-color 2>&1 | tail -10
```
Expected: 0 failures

- [ ] **Step 4: Commit**

```bash
git add spec/features/student_tutor_chips_spec.rb
git commit -m "test(tutor): add E2E chip spec — guiding/validating/send behaviors"
```

---

## Task 9: Push et PR

- [ ] **Step 1: Vérifier l'état de la branche**

```bash
git log main..HEAD --oneline
git status
```

- [ ] **Step 2: Push**

```bash
git push origin HEAD
```

- [ ] **Step 3: Créer la PR**

```bash
gh pr create \
  --title "feat(tutor): contextual chips in Tibo's drawer (phase-driven, ActionCable)" \
  --body "$(cat <<'EOF'
## Summary

- Add `Tutor::ChipsPresenter` — pure service mapping phase/hints_used → chip descriptors
- Add `_chips.html.erb` partial — renders send/confidence/navigate chips with rad-* design
- Add `tutor-chips` Turbo Frame in drawer — cleared on send, injected on ActionCable done
- `BroadcastMessage` now sends `chips_html` in the done payload (renders chips server-side)
- `tutor_chat_controller.js` dispatches chip clicks: send message, PATCH confidence, navigate
- Phase `validating` disables input and shows 5 stacked confidence chips
- Fixes 3 previously-pending scenarios in `student_tutor_full_flow_spec.rb`

## Test plan

- [ ] `bundle exec rspec spec/services/tutor/chips_presenter_spec.rb` — unit presenter
- [ ] `bundle exec rspec spec/features/student_tutor_chips_spec.rb` — E2E chips
- [ ] `bundle exec rspec spec/features/student_tutor_full_flow_spec.rb` — 3 re-activated scenarios pass
- [ ] `bundle exec rspec spec/` — full suite green

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

---

## Self-Review

**Spec coverage check:**

| Spec requirement | Task |
|---|---|
| ChipsPresenter — phase → descriptors | Task 1 |
| `_chips.html.erb` — 3 actions | Task 2 |
| `tutor-chips` frame dans drawer | Task 3 |
| BroadcastMessage — chips_html in done | Task 4 |
| Clear chips on send, inject on done | Task 5 |
| Chip click dispatch (send/confidence/navigate) | Task 5 |
| Validating — input disabled | Task 5 |
| Confidence stream → feedback chips | Task 6 |
| 3 pending scenarios activated | Task 7 |
| Feature spec E2E | Task 8 |

**Placeholders:** aucun TBD/TODO.

**Type consistency:**
- `chips_html` utilisé partout de façon cohérente (Task 4 → Task 5)
- `Tutor::ChipsPresenter.call(phase:, hints_used:)` — signature cohérente Tasks 1 et 2
- `data-chip-action`, `data-chip-text`, `data-chip-level`, `data-confidence-url` — attributs cohérents Tasks 2 et 5
- `#tutor-chips` — id cohérent Tasks 3, 5, 6, 7, 8
