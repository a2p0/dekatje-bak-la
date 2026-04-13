# Vague 4 — Interface Hotwire : Plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Construire l'interface Hotwire complète du tuteur : drawer chat persistant, streaming temps réel via ActionCable, optimistic UI, formulaire d'auto-évaluation inline, et bouton d'activation depuis la page sujet.

**Architecture:** Trois Stimulus controllers (`chat-drawer`, `tutor-chat`, `confidence-form`). Le drawer est un état UI pur — aucune mutation lifecycle. Le streaming arrive via `ActionCable` sur `TutorChannel` (stream `conversation_{id}`). `TutorStreamJob` diffuse des messages typés `{ type: "token"|"done"|"data_hints"|"error", ... }`. La route `PATCH /conversations/:id/confidence` met à jour `question_states[q_id].last_confidence` et déclenche `ApplyToolCalls` pour avancer le lifecycle.

**Tech Stack:** Rails 8, Hotwire (Turbo Frames + Turbo Streams), Stimulus, ActionCable, ViewComponent, Capybara (E2E)

**Prérequis Vague 3 accomplie :**
- `Message` model (table `messages`, colonnes `role`, `content`, `conversation_id`, `chunk_index`, `streaming_finished_at`)
- `Conversation` model avec AASM lifecycle (`lifecycle_state`: `disabled / active / validating / feedback / done`)
- `TutorState` typed Data class + `QuestionState` nested type
- `Tutor::ProcessMessage` pipeline (7 étapes: BuildContext → CallLlm → FilterSpottingOutput → ParseToolCalls → ApplyToolCalls → UpdateTutorState → BroadcastMessage)
- `Tutor::BroadcastMessage` service (`ActionCable.server.broadcast(...)`)
- `ConversationChannel` (streams depuis `"conversation_{id}"`)
- `DataHintsComponent` ViewComponent
- `InjectDataHints` service
- `spec/support/fake_ruby_llm.rb` avec `FakeRubyLlm.setup_stub`
- `Classroom#tutor_free_mode_enabled` column (boolean, depuis Vague 1)
- `Conversation` appartient à `(student, subject)` — une conversation par (student, subject)

**Note sur le code existant :** Les fichiers `chat_controller.js`, `_chat_drawer.html.erb`, et les routes/actions `conversations#create`/`conversations#message` existent dans le codebase actuel mais sont basés sur l'ancienne architecture (conversation par question, `messages` JSONB). Ils ont été supprimés ou remplacés dans Vague 1. Cette vague reconstruit tout proprement à partir de la nouvelle architecture.

---

## Task 1 — Mettre à jour `TutorStreamJob` pour diffuser des messages typés

Le job actuel diffuse `{ token: }` et `{ done: true }`. La nouvelle architecture diffuse `{ type:, ... }` pour que le Stimulus controller puisse router sans ambiguité.

**Files:**
- Modify: `app/jobs/tutor_stream_job.rb`
- Modify: `spec/jobs/tutor_stream_job_spec.rb` (remettre en `RSpec.describe`, adapter)
- Commit: `feat(tutor): broadcast typed messages (token/done/error) from TutorStreamJob`

### Steps

- [ ] Écrire les specs failing d'abord. Dans `spec/jobs/tutor_stream_job_spec.rb`, remplacer `RSpec.xdescribe` par `RSpec.describe` et réécrire le contenu :

  ```ruby
  # spec/jobs/tutor_stream_job_spec.rb
  require "rails_helper"

  RSpec.describe TutorStreamJob, type: :job do
    include ActiveJob::TestHelper

    let(:teacher)   { create(:user) }
    let(:classroom) { create(:classroom, owner: teacher) }
    let(:student)   { create(:student, classroom: classroom, api_key: "sk-test", api_provider: :anthropic) }
    let(:subject_record) { create(:subject, owner: teacher, status: :published) }
    let(:part)      { create(:part, subject: subject_record) }
    let(:question)  { create(:question, part: part) }
    let!(:conversation) do
      create(:conversation,
        student: student,
        subject: subject_record,
        lifecycle_state: "active")
    end

    before do
      create(:message, conversation: conversation, role: :user, content: "Aide-moi")
    end

    it "broadcasts typed token messages during streaming" do
      broadcasted = []
      allow(ActionCable.server).to receive(:broadcast) do |channel, data|
        broadcasted << data if channel == "conversation_#{conversation.id}"
      end

      client_double = instance_double("Object")
      allow(AiClientFactory).to receive(:build).and_return(client_double)
      allow(client_double).to receive(:stream).and_yield("Bonjour ")
                                              .and_yield("élève")

      described_class.perform_now(conversation.id)

      token_msgs = broadcasted.select { |d| d[:type] == "token" }
      expect(token_msgs.map { |d| d[:token] }).to eq(["Bonjour ", "élève"])
    end

    it "broadcasts a typed done message with rendered HTML when streaming finishes" do
      allow(ActionCable.server).to receive(:broadcast)

      client_double = instance_double("Object")
      allow(AiClientFactory).to receive(:build).and_return(client_double)
      allow(client_double).to receive(:stream).and_yield("Réponse complète.")

      described_class.perform_now(conversation.id)

      done_calls = []
      allow(ActionCable.server).to receive(:broadcast) do |_ch, data|
        done_calls << data if data[:type] == "done"
      end

      described_class.perform_now(conversation.id)

      # At least one broadcast with type: "done" must have been sent
      expect(ActionCable.server).to have_received(:broadcast)
        .with("conversation_#{conversation.id}", hash_including(type: "done"))
    end

    it "broadcasts a typed error message on API failure" do
      allow(ActionCable.server).to receive(:broadcast)

      client_double = instance_double("Object")
      allow(AiClientFactory).to receive(:build).and_return(client_double)
      allow(client_double).to receive(:stream).and_raise(RuntimeError.new("401 Unauthorized"))

      described_class.perform_now(conversation.id)

      expect(ActionCable.server).to have_received(:broadcast)
        .with("conversation_#{conversation.id}", hash_including(type: "error"))
    end
  end
  ```

- [ ] Lancer les specs et confirmer qu'elles échouent :
  ```bash
  bundle exec rspec spec/jobs/tutor_stream_job_spec.rb --format documentation 2>&1 | tail -15
  ```
  Résultat attendu : erreurs sur les types de messages (`{ token: }` vs `{ type: "token" }`).

- [ ] Modifier `app/jobs/tutor_stream_job.rb` pour diffuser des messages typés :

  ```ruby
  # app/jobs/tutor_stream_job.rb
  class TutorStreamJob < ApplicationJob
    queue_as :default

    def perform(conversation_id)
      conversation = Conversation.find(conversation_id)
      last_msg = conversation.messages.order(:created_at).last
      return if last_msg.nil? || last_msg.role == "assistant"

      student  = conversation.student
      question = last_msg.question || conversation.messages.where(role: "user").order(:created_at).last&.question

      system_prompt = BuildTutorPrompt.call(question: question, student: student)

      client = AiClientFactory.build(
        provider: student.api_provider,
        api_key:  student.api_key,
        model:    student.effective_model
      )

      full_response = ""
      api_messages  = conversation.messages.order(:created_at).map { |m| { role: m.role, content: m.content } }

      client.stream(
        messages:   api_messages,
        system:     system_prompt,
        max_tokens: 2048,
        temperature: 0.7
      ) do |token|
        full_response += token
        ActionCable.server.broadcast(
          "conversation_#{conversation.id}",
          { type: "token", token: token }
        )
      end

      msg = conversation.messages.create!(
        role:    :assistant,
        content: full_response,
        streaming_finished_at: Time.current
      )

      conversation.update!(
        tokens_used: conversation.tokens_used.to_i + estimate_tokens(full_response),
        provider_used: student.api_provider.to_s
      )

      ActionCable.server.broadcast(
        "conversation_#{conversation.id}",
        { type: "done", message_id: msg.id, html: render_message(msg) }
      )
    rescue RuntimeError => e
      if e.message.match?(/429|529|503/) && (@retries ||= 0) < 2
        @retries += 1
        sleep(@retries * 3)
        retry
      end
      handle_error(conversation, e)
    rescue Faraday::UnauthorizedError => e
      handle_error(conversation, e)
    rescue Faraday::TimeoutError => e
      handle_error(conversation, e, "Le serveur n'a pas répondu. Réessayez.")
    rescue StandardError => e
      handle_error(conversation, e, "Une erreur est survenue. Réessayez.")
    end

    private

    def estimate_tokens(text)
      (text.length / 4.0).ceil
    end

    def render_message(message)
      ApplicationController.render(
        partial: "student/conversations/message",
        locals:  { message: message }
      )
    end

    def handle_error(conversation, error, custom_message = nil)
      msg = custom_message || error_message_for(error)
      ActionCable.server.broadcast(
        "conversation_#{conversation.id}",
        { type: "error", error: msg }
      )
      Rails.logger.error("[TutorStreamJob] #{error.class}: #{error.message}")
    end

    def error_message_for(error)
      case error.message
      when /401/ then "Clé API invalide. Vérifiez vos réglages."
      when /402/ then "Crédits insuffisants sur votre compte."
      when /429/ then "Trop de requêtes. Réessayez dans quelques secondes."
      when /529/, /503/ then "Le service IA est temporairement surchargé. Réessayez."
      when /timeout/i then "Le serveur n'a pas répondu. Réessayez."
      else "Erreur de communication avec l'IA. Réessayez."
      end
    end
  end
  ```

- [ ] Lancer les specs et confirmer qu'elles passent :
  ```bash
  bundle exec rspec spec/jobs/tutor_stream_job_spec.rb --format documentation 2>&1 | tail -10
  ```
  Résultat attendu : `3 examples, 0 failures`.

- [ ] Commit :
  ```bash
  git add app/jobs/tutor_stream_job.rb spec/jobs/tutor_stream_job_spec.rb
  git commit -m "feat(tutor): broadcast typed messages (token/done/error) from TutorStreamJob"
  ```

---

## Task 2 — Partial `_message.html.erb` pour afficher un Message

**Files:**
- Create: `app/views/student/conversations/_message.html.erb`
- Create: `spec/requests/student/conversations_spec.rb` (ajouter test du rendu partiel, ou nouveau fichier)
- Commit: `feat(tutor): add message partial for conversation rendering`

### Steps

- [ ] Écrire un test request minimal pour vérifier que le partial se rend sans erreur. Créer ou ajouter dans `spec/requests/student/conversations_spec.rb` un exemple qui charge la page question et vérifie que le drawer contient les messages préchargés. Alternativement, tester le rendu du partial dans un component spec. Pour simplifier, utiliser un test de rendu inline :

  ```ruby
  # Dans spec/requests/student/conversations_spec.rb (nouveaux exemples, ne pas supprimer les existants)
  # Ajouter à la fin de la describe block existante :

  describe "message partial rendering" do
    it "renders user message bubble with correct alignment class" do
      conversation = create(:conversation,
        student: student,
        subject: subject_record,
        lifecycle_state: "active")
      msg = create(:message, conversation: conversation, role: :user, content: "Ma question")

      html = ApplicationController.render(
        partial: "student/conversations/message",
        locals:  { message: msg }
      )

      expect(html).to include("Ma question")
      expect(html).to include("self-end")
    end

    it "renders assistant message bubble with correct alignment class" do
      conversation = create(:conversation,
        student: student,
        subject: subject_record,
        lifecycle_state: "active")
      msg = create(:message, conversation: conversation, role: :assistant, content: "Ma réponse")

      html = ApplicationController.render(
        partial: "student/conversations/message",
        locals:  { message: msg }
      )

      expect(html).to include("Ma réponse")
      expect(html).to include("self-start")
    end
  end
  ```

- [ ] Lancer les specs pour confirmer l'échec :
  ```bash
  bundle exec rspec spec/requests/student/conversations_spec.rb --format documentation 2>&1 | tail -10
  ```
  Résultat attendu : `ActionView::MissingTemplate` ou `No such file`.

- [ ] Créer `app/views/student/conversations/_message.html.erb` :

  ```erb
  <%# app/views/student/conversations/_message.html.erb %>
  <% role = message.role.to_s %>

  <% if role == "user" %>
    <div class="self-end bg-gradient-to-br from-indigo-500 to-violet-500 text-white px-3 py-2 rounded-2xl rounded-br-sm max-w-[85%] text-sm leading-relaxed break-words"
         data-message-id="<%= message.id %>"
         data-message-role="user">
      <%= message.content %>
    </div>

  <% elsif role == "assistant" %>
    <div class="self-start bg-slate-100 dark:bg-slate-800 text-slate-800 dark:text-slate-200 px-3 py-2 rounded-2xl rounded-bl-sm max-w-[85%] text-sm leading-relaxed break-words"
         data-message-id="<%= message.id %>"
         data-message-role="assistant">
      <%= message.content %>
    </div>

  <% elsif role == "system" %>
    <div class="self-center text-xs italic text-slate-400 dark:text-slate-500 text-center max-w-[85%]"
         data-message-id="<%= message.id %>"
         data-message-role="system">
      <%= message.content %>
    </div>
  <% end %>
  ```

- [ ] Lancer les specs et confirmer qu'elles passent :
  ```bash
  bundle exec rspec spec/requests/student/conversations_spec.rb --format documentation 2>&1 | tail -10
  ```
  Résultat attendu : `0 failures`.

- [ ] Commit :
  ```bash
  git add app/views/student/conversations/_message.html.erb spec/requests/student/conversations_spec.rb
  git commit -m "feat(tutor): add message partial for conversation rendering"
  ```

---

## Task 3 — Partial `_confidence_form.html.erb` et Stimulus controller `confidence-form`

**Files:**
- Create: `app/views/student/conversations/_confidence_form.html.erb`
- Create: `app/javascript/controllers/confidence_form_controller.js`
- Commit: `feat(tutor): add confidence form partial and Stimulus controller`

### Steps

- [ ] Écrire un test request pour le partiel de confiance. Ajouter dans `spec/requests/student/conversations_spec.rb` :

  ```ruby
  describe "confidence form partial rendering" do
    it "renders 5 confidence buttons" do
      conversation = create(:conversation,
        student: student,
        subject: subject_record,
        lifecycle_state: "validating")

      html = ApplicationController.render(
        partial: "student/conversations/confidence_form",
        locals:  {
          conversation: conversation,
          question_id:  question.id,
          access_code:  classroom.access_code
        }
      )

      expect(html).to include("Très peu sûr")
      expect(html).to include("Très sûr")
      (1..5).each { |n| expect(html).to include("value=\"#{n}\"") }
    end
  end
  ```

- [ ] Confirmer l'échec :
  ```bash
  bundle exec rspec spec/requests/student/conversations_spec.rb --format documentation 2>&1 | tail -10
  ```

- [ ] Créer `app/views/student/conversations/_confidence_form.html.erb` :

  ```erb
  <%# app/views/student/conversations/_confidence_form.html.erb %>
  <%= turbo_frame_tag "confidence-form-#{question_id}" do %>
    <div class="self-start mt-2 bg-slate-50 dark:bg-slate-800/60 border border-slate-200 dark:border-slate-700 rounded-2xl p-4 max-w-[90%]"
         data-controller="confidence-form"
         data-confidence-form-url-value="<%= student_conversation_confidence_path(access_code: access_code, id: conversation.id) %>">
      <p class="text-xs font-medium text-slate-600 dark:text-slate-400 mb-3">
        À quel point étais-tu sûr(e) de ta réponse ?
      </p>
      <div class="flex gap-2 flex-wrap">
        <% confidence_labels = {
          1 => "Très peu sûr",
          2 => "Peu sûr",
          3 => "Moyennement sûr",
          4 => "Assez sûr",
          5 => "Très sûr"
        } %>
        <% (1..5).each do |level| %>
          <button type="button"
                  value="<%= level %>"
                  data-confidence-form-target="button"
                  data-action="click->confidence-form#submit"
                  title="<%= confidence_labels[level] %>"
                  class="w-9 h-9 rounded-full border border-slate-300 dark:border-slate-600 text-sm font-semibold text-slate-600 dark:text-slate-300 hover:bg-indigo-50 dark:hover:bg-indigo-500/10 hover:border-indigo-400 hover:text-indigo-600 transition-colors cursor-pointer bg-white dark:bg-slate-800">
            <%= level %>
          </button>
        <% end %>
      </div>
      <p class="text-[10px] text-slate-400 dark:text-slate-500 mt-2">
        1 = <%= confidence_labels[1] %> &nbsp;·&nbsp; 5 = <%= confidence_labels[5] %>
      </p>
    </div>
  <% end %>
  ```

- [ ] Créer `app/javascript/controllers/confidence_form_controller.js` :

  ```javascript
  // app/javascript/controllers/confidence_form_controller.js
  import { Controller } from "@hotwired/stimulus"

  export default class extends Controller {
    static targets = ["button"]
    static values  = { url: String }

    async submit(event) {
      const level = event.currentTarget.value
      if (!level) return

      // Prevent double-submit
      this.buttonTargets.forEach(btn => {
        btn.disabled = true
        btn.classList.add("opacity-50", "cursor-not-allowed")
      })

      try {
        const response = await fetch(this.urlValue, {
          method: "PATCH",
          headers: {
            "Content-Type": "application/json",
            "X-CSRF-Token": this.#csrfToken(),
            "Accept": "text/vnd.turbo-stream.html"
          },
          body: JSON.stringify({ level: parseInt(level, 10) })
        })

        if (response.ok) {
          const html = await response.text()
          Turbo.renderStreamMessage(html)
        } else {
          this.#reenableButtons()
        }
      } catch {
        this.#reenableButtons()
      }
    }

    #reenableButtons() {
      this.buttonTargets.forEach(btn => {
        btn.disabled = false
        btn.classList.remove("opacity-50", "cursor-not-allowed")
      })
    }

    #csrfToken() {
      return document.querySelector('meta[name="csrf-token"]')?.content || ""
    }
  }
  ```

- [ ] Lancer les specs pour confirmer le partiel :
  ```bash
  bundle exec rspec spec/requests/student/conversations_spec.rb --format documentation 2>&1 | tail -10
  ```
  Résultat attendu : `0 failures`.

- [ ] Commit :
  ```bash
  git add app/views/student/conversations/_confidence_form.html.erb \
          app/javascript/controllers/confidence_form_controller.js \
          spec/requests/student/conversations_spec.rb
  git commit -m "feat(tutor): add confidence form partial and Stimulus controller"
  ```

---

## Task 4 — Route et action `confidence` dans `Student::ConversationsController`

**Files:**
- Modify: `config/routes.rb`
- Modify: `app/controllers/student/conversations_controller.rb`
- Create: `app/views/student/conversations/confidence.turbo_stream.erb`
- Modify: `spec/requests/student/conversations_spec.rb`
- Commit: `feat(tutor): add PATCH conversations#confidence endpoint`

### Steps

- [ ] Écrire les specs request failing. Ajouter dans `spec/requests/student/conversations_spec.rb` :

  ```ruby
  describe "PATCH /conversations/:id/confidence" do
    let!(:conversation) do
      create(:conversation,
        student: student,
        subject: subject_record,
        lifecycle_state: "validating",
        tutor_state: TutorState.new(
          current_phase:        "validating",
          current_question_id:  question.id,
          concepts_mastered:    [],
          concepts_to_revise:   [],
          discouragement_level: 0,
          question_states:      {
            question.id.to_s => QuestionState.new(
              step: "initial", hints_used: 0, last_confidence: nil,
              error_types: [], completed_at: nil
            )
          }
        )
      )
    end

    it "saves the confidence level and returns a Turbo Stream" do
      patch student_conversation_confidence_path(
              access_code: classroom.access_code,
              id: conversation.id),
            params: { level: 3 },
            headers: { "Accept" => "text/vnd.turbo-stream.html" },
            as: :json

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include("turbo-stream")

      conversation.reload
      q_state = conversation.tutor_state.question_states[question.id.to_s]
      expect(q_state.last_confidence).to eq(3)
    end

    it "rejects invalid confidence levels" do
      patch student_conversation_confidence_path(
              access_code: classroom.access_code,
              id: conversation.id),
            params: { level: 9 },
            headers: { "Accept" => "text/vnd.turbo-stream.html" },
            as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "prevents accessing another student's conversation" do
      other_student      = create(:student, classroom: classroom)
      other_conversation = create(:conversation,
        student: other_student,
        subject: subject_record,
        lifecycle_state: "validating")

      patch student_conversation_confidence_path(
              access_code: classroom.access_code,
              id: other_conversation.id),
            params: { level: 3 },
            headers: { "Accept" => "text/vnd.turbo-stream.html" },
            as: :json

      expect(response).to have_http_status(:not_found)
    end
  end
  ```

- [ ] Confirmer l'échec (route manquante) :
  ```bash
  bundle exec rspec spec/requests/student/conversations_spec.rb --format documentation 2>&1 | tail -10
  ```

- [ ] Ajouter la route dans `config/routes.rb`. Localiser le bloc existant :
  ```ruby
  resources :conversations, only: [ :create ], controller: "student/conversations" do
    member do
      post :message
    end
  end
  ```
  Le remplacer par :
  ```ruby
  resources :conversations, only: [ :create ], controller: "student/conversations" do
    member do
      post  :message
      patch :confidence
    end
  end
  ```

- [ ] Ajouter l'action `confidence` dans `app/controllers/student/conversations_controller.rb` :

  ```ruby
  # Ajouter avant `private` :

  def confidence
    level = params[:level].to_i
    unless (1..5).cover?(level)
      return render json: { error: "Niveau invalide (1-5 requis)." },
                    status: :unprocessable_entity
    end

    q_id  = @conversation.tutor_state.current_question_id
    state = @conversation.tutor_state.question_states[q_id.to_s]
    return render json: { error: "Question courante introuvable." }, status: :not_found unless state

    updated_state = state.with(last_confidence: level)
    new_ts = @conversation.tutor_state.with(
      question_states: @conversation.tutor_state.question_states.merge(q_id.to_s => updated_state)
    )
    @conversation.update!(tutor_state: new_ts)

    # Trigger feedback phase transition via pipeline
    Tutor::ProcessMessage.call(
      conversation: @conversation,
      student_input: nil,
      tool_name: "transition",
      tool_args: { phase: "feedback" }
    )

    render turbo_stream: render_to_string(
      "student/conversations/confidence",
      formats: [:turbo_stream],
      locals: { conversation: @conversation, question_id: q_id }
    )
  end
  ```

  Ajouter aussi `before_action :set_conversation, only: [ :message, :confidence ]` (remplacer l'existant) et ajouter l'instance variable pour rendre la template Turbo Stream :

  ```ruby
  before_action :set_conversation, only: [ :message, :confidence ]
  ```

- [ ] Créer la Turbo Stream template `app/views/student/conversations/confidence.turbo_stream.erb` :

  ```erb
  <%# app/views/student/conversations/confidence.turbo_stream.erb %>
  <%= turbo_stream.replace "confidence-form-#{question_id}" do %>
    <div class="self-start mt-2 bg-emerald-50 dark:bg-emerald-900/20 border border-emerald-200 dark:border-emerald-700 rounded-2xl px-4 py-3 max-w-[90%] text-sm text-emerald-700 dark:text-emerald-300">
      Confiance enregistrée ✓
    </div>
  <% end %>
  ```

- [ ] Lancer les specs :
  ```bash
  bundle exec rspec spec/requests/student/conversations_spec.rb --format documentation 2>&1 | tail -15
  ```
  Résultat attendu : `0 failures`.

- [ ] Commit :
  ```bash
  git add config/routes.rb \
          app/controllers/student/conversations_controller.rb \
          app/views/student/conversations/confidence.turbo_stream.erb \
          spec/requests/student/conversations_spec.rb
  git commit -m "feat(tutor): add PATCH conversations#confidence endpoint"
  ```

---

## Task 5 — Stimulus controller `chat-drawer`

**Files:**
- Create: `app/javascript/controllers/chat_drawer_controller.js`
- Commit: `feat(tutor): add chat-drawer Stimulus controller (open/close drawer)`

### Steps

- [ ] Le controller `chat-drawer` est responsable uniquement de l'animation CSS du panneau latéral. Aucune mutation de lifecycle. Créer `app/javascript/controllers/chat_drawer_controller.js` :

  ```javascript
  // app/javascript/controllers/chat_drawer_controller.js
  import { Controller } from "@hotwired/stimulus"

  export default class extends Controller {
    static targets = ["drawer", "backdrop"]

    open() {
      this.drawerTarget.classList.remove("translate-x-full")
      this.drawerTarget.classList.add("translate-x-0")
      this.backdropTarget.classList.remove("hidden")
      this.drawerTarget.setAttribute("aria-hidden", "false")
      this.element.querySelectorAll("[data-chat-drawer-toggle]").forEach(btn => {
        btn.setAttribute("aria-expanded", "true")
      })
      // Focus le champ de saisie si présent
      const input = this.drawerTarget.querySelector("[data-tutor-chat-target='input']")
      if (input) setTimeout(() => input.focus(), 50)
    }

    close() {
      this.drawerTarget.classList.add("translate-x-full")
      this.drawerTarget.classList.remove("translate-x-0")
      this.backdropTarget.classList.add("hidden")
      this.drawerTarget.setAttribute("aria-hidden", "true")
      this.element.querySelectorAll("[data-chat-drawer-toggle]").forEach(btn => {
        btn.setAttribute("aria-expanded", "false")
      })
    }
  }
  ```

- [ ] Vérifier que le controller apparaît dans le bundle (pas de test unitaire possible sans jest — la vérification se fera en E2E) :
  ```bash
  grep -r "chat_drawer_controller" /home/fz/Documents/Dev/claudeCLI/DekatjeBakLa/app/javascript/
  ```
  Résultat attendu : le fichier nouvellement créé.

- [ ] Commit :
  ```bash
  git add app/javascript/controllers/chat_drawer_controller.js
  git commit -m "feat(tutor): add chat-drawer Stimulus controller (open/close drawer)"
  ```

---

## Task 6 — Stimulus controller `tutor-chat`

**Files:**
- Create: `app/javascript/controllers/tutor_chat_controller.js`
- Commit: `feat(tutor): add tutor-chat Stimulus controller (messaging + ActionCable streaming)`

### Steps

- [ ] Créer `app/javascript/controllers/tutor_chat_controller.js` :

  ```javascript
  // app/javascript/controllers/tutor_chat_controller.js
  import { Controller } from "@hotwired/stimulus"
  import { createConsumer } from "@rails/actioncable"

  export default class extends Controller {
    static targets  = ["messages", "input", "sendButton", "streamingPlaceholder"]
    static values   = {
      conversationId: String,
      messagesUrl:    String,
      channelName:    String
    }

    connect() {
      this.consumer     = null
      this.subscription = null
      this.isStreaming  = false

      if (this.conversationIdValue) {
        this.#subscribe(this.conversationIdValue)
      }

      this.#scrollToBottom()
    }

    disconnect() {
      this.#unsubscribe()
    }

    // Called by button click or Enter key
    async send(event) {
      if (event?.type === "keydown" && event.key !== "Enter") return
      if (this.isStreaming) return

      const content = this.inputTarget.value.trim()
      if (!content) return

      this.#hideError()
      this.#appendOptimisticMessage(content)
      this.inputTarget.value = ""
      this.#setStreaming(true)

      try {
        const response = await fetch(this.messagesUrlValue, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "X-CSRF-Token": this.#csrfToken(),
            "Accept":       "application/json"
          },
          body: JSON.stringify({ content })
        })

        if (!response.ok) {
          const data = await response.json().catch(() => ({}))
          this.#showError(data.error || "Erreur lors de l'envoi du message.")
          this.#setStreaming(false)
        }
        // On success: streaming placeholder already shown, response arrives via ActionCable
      } catch {
        this.#showError("Erreur de connexion. Vérifiez votre connexion internet.")
        this.#setStreaming(false)
      }
    }

    // ActionCable message dispatch
    #handleReceived(data) {
      switch (data.type) {
        case "token":
          this.#onToken(data.token)
          break
        case "done":
          this.#onDone(data.html, data.message_id)
          break
        case "data_hints":
          this.#onDataHints(data.html)
          break
        case "error":
          this.#onError(data.error)
          break
      }
    }

    #onToken(token) {
      this.streamingPlaceholderTarget.classList.remove("hidden")
      this.streamingPlaceholderTarget.textContent += token
      this.#scrollToBottom()
    }

    #onDone(html, _messageId) {
      this.streamingPlaceholderTarget.textContent = ""
      this.streamingPlaceholderTarget.classList.add("hidden")
      if (html) {
        this.messagesTarget.insertAdjacentHTML("beforeend", html)
      }
      this.#setStreaming(false)
      this.#scrollToBottom()
    }

    #onDataHints(html) {
      if (html) {
        this.messagesTarget.insertAdjacentHTML("beforeend", html)
        this.#scrollToBottom()
      }
    }

    #onError(message) {
      this.streamingPlaceholderTarget.textContent = ""
      this.streamingPlaceholderTarget.classList.add("hidden")
      this.#showError(message)
      this.#setStreaming(false)
    }

    #appendOptimisticMessage(content) {
      const div = document.createElement("div")
      div.classList.add(
        "self-end",
        "bg-gradient-to-br", "from-indigo-500", "to-violet-500",
        "text-white", "px-3", "py-2",
        "rounded-2xl", "rounded-br-sm",
        "max-w-[85%]", "text-sm", "leading-relaxed", "break-words"
      )
      div.dataset.messageRole = "user"
      div.dataset.optimistic  = "true"
      div.textContent = content
      this.messagesTarget.appendChild(div)
      this.#scrollToBottom()
    }

    #setStreaming(value) {
      this.isStreaming = value
      this.inputTarget.disabled      = value
      this.sendButtonTarget.disabled = value
      if (value) {
        this.sendButtonTarget.classList.add("opacity-50")
      } else {
        this.sendButtonTarget.classList.remove("opacity-50")
      }
    }

    #subscribe(conversationId) {
      this.#unsubscribe()
      this.consumer = createConsumer()
      const controller = this

      this.subscription = this.consumer.subscriptions.create(
        { channel: "TutorChannel", conversation_id: conversationId },
        {
          received(data) {
            controller.#handleReceived(data)
          },
          connected() {
            // On reconnect: reload if last message has no streaming_finished_at
            // (handled server-side — the job will re-enqueue)
          }
        }
      )
    }

    #unsubscribe() {
      this.subscription?.unsubscribe()
      this.subscription = null
      this.consumer?.disconnect()
      this.consumer = null
    }

    #showError(message) {
      let errorEl = this.element.querySelector("[data-tutor-chat-error]")
      if (!errorEl) {
        errorEl = document.createElement("div")
        errorEl.dataset.tutorChatError = "true"
        errorEl.setAttribute("role", "alert")
        errorEl.classList.add(
          "mx-4", "mb-2", "px-3", "py-2",
          "bg-red-50", "dark:bg-rose-950/50",
          "border", "border-rose-200", "dark:border-rose-900",
          "text-rose-700", "dark:text-rose-300",
          "rounded-lg", "text-xs"
        )
        this.inputTarget.closest(".px-4")?.before(errorEl)
      }
      errorEl.textContent = message
      errorEl.classList.remove("hidden")
    }

    #hideError() {
      const errorEl = this.element.querySelector("[data-tutor-chat-error]")
      if (errorEl) errorEl.classList.add("hidden")
    }

    #scrollToBottom() {
      this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight
    }

    #csrfToken() {
      return document.querySelector('meta[name="csrf-token"]')?.content || ""
    }
  }
  ```

- [ ] Commit :
  ```bash
  git add app/javascript/controllers/tutor_chat_controller.js
  git commit -m "feat(tutor): add tutor-chat Stimulus controller (messaging + ActionCable streaming)"
  ```

---

## Task 7 — Partial `_drawer.html.erb` pour le chat

**Files:**
- Create: `app/views/student/conversations/_drawer.html.erb`
- Commit: `feat(tutor): add conversation drawer partial`

### Steps

- [ ] Créer `app/views/student/conversations/_drawer.html.erb`. Ce partial contient le drawer complet. Il est rendu une fois par page (dans la page question). Il utilise à la fois `chat-drawer` et `tutor-chat` :

  ```erb
  <%# app/views/student/conversations/_drawer.html.erb %>
  <%# Locals: conversation (Conversation | nil), question (Question), access_code (String) %>

  <%# Backdrop %>
  <div data-chat-drawer-target="backdrop"
       data-action="click->chat-drawer#close"
       class="hidden fixed inset-0 bg-black/50 z-[var(--z-backdrop)]">
  </div>

  <%# Drawer panel %>
  <div id="tutor-chat-drawer"
       data-chat-drawer-target="drawer"
       data-controller="focus-trap"
       data-action="focus-trap:close->chat-drawer#close"
       role="dialog"
       aria-modal="true"
       aria-label="Tutorat IA"
       aria-hidden="true"
       class="fixed top-0 right-0 bottom-0 w-full lg:w-[420px] bg-white dark:bg-slate-900/95 border-l border-slate-200 dark:border-indigo-500/15 z-[var(--z-chat-drawer)] translate-x-full transition-transform duration-200 ease-in-out flex flex-col backdrop-blur-sm"
       <% if conversation %>
         data-controller="tutor-chat"
         data-tutor-chat-conversation-id-value="<%= conversation.id %>"
         data-tutor-chat-messages-url-value="<%= message_student_conversation_path(access_code: access_code, id: conversation.id) %>"
         data-tutor-chat-channel-name-value="conversation_<%= conversation.id %>"
       <% end %>>

    <%# Header %>
    <div class="px-4 py-3 border-b border-slate-200 dark:border-indigo-500/15 shrink-0 bg-slate-50 dark:bg-slate-900/80">
      <div class="flex items-center justify-between mb-2">
        <span class="text-sm font-semibold text-slate-800 dark:text-slate-200">Tutorat IA</span>
        <button data-action="click->chat-drawer#close"
                aria-label="Fermer le tutorat"
                class="p-1 text-slate-500 hover:text-slate-700 dark:hover:text-slate-200 transition-colors cursor-pointer bg-transparent border-none text-lg leading-none">
          ✕
        </button>
      </div>
      <%# Question context reminder %>
      <div class="bg-indigo-50 dark:bg-indigo-500/10 border border-indigo-200 dark:border-indigo-500/20 rounded-lg px-3 py-2">
        <div class="flex justify-between items-start gap-2">
          <span class="text-xs font-semibold text-indigo-700 dark:text-indigo-300">
            Q<%= question.number %> &middot; <%= question.points %> pts
          </span>
        </div>
        <p class="text-xs text-slate-700 dark:text-slate-300 mt-1 line-clamp-2"><%= question.label %></p>
      </div>
    </div>

    <%# Messages area %>
    <div data-tutor-chat-target="messages"
         class="flex-1 overflow-y-auto p-4 flex flex-col gap-3">
      <% if conversation&.messages&.any? %>
        <% conversation.messages.order(:created_at).each do |msg| %>
          <%= render "student/conversations/message", message: msg %>
        <% end %>
      <% else %>
        <div class="text-slate-600 dark:text-slate-500 text-sm text-center mt-10">
          Posez votre question pour commencer le tutorat.
        </div>
      <% end %>
    </div>

    <%# Streaming placeholder %>
    <div data-tutor-chat-target="streamingPlaceholder"
         aria-live="polite"
         class="hidden self-start bg-slate-100 dark:bg-slate-800 text-slate-800 dark:text-slate-200 px-3 py-2 rounded-2xl rounded-bl-sm max-w-[85%] text-sm leading-relaxed mx-4 mb-3 break-words">
    </div>

    <%# Input area %>
    <div class="px-4 py-3 border-t border-slate-200 dark:border-indigo-500/15 shrink-0">
      <div class="flex gap-2">
        <label for="tutor-chat-input" class="sr-only">Écrivez votre question au tuteur</label>
        <input data-tutor-chat-target="input"
               data-action="keydown.enter->tutor-chat#send"
               type="text"
               id="tutor-chat-input"
               aria-label="Écrivez votre question au tuteur"
               placeholder="Écrivez votre question..."
               <% unless conversation %> disabled <% end %>
               class="flex-1 px-3 py-2 bg-white dark:bg-slate-800/80 border border-slate-200 dark:border-indigo-500/15 rounded-xl text-sm text-slate-800 dark:text-slate-200 placeholder-slate-400 dark:placeholder-slate-500 focus:outline-none focus:ring-2 focus:ring-indigo-500 disabled:opacity-50"
               autocomplete="off">
        <button data-tutor-chat-target="sendButton"
                data-action="click->tutor-chat#send"
                aria-label="Envoyer"
                <% unless conversation %> disabled <% end %>
                class="px-4 py-2 bg-gradient-to-br from-indigo-500 to-violet-500 hover:from-indigo-600 hover:to-violet-600 text-white rounded-xl text-sm font-medium transition-all cursor-pointer whitespace-nowrap border-none shadow-[0_0_14px_rgba(99,102,241,0.3)] disabled:opacity-50 disabled:cursor-not-allowed">
          Envoyer
        </button>
      </div>
    </div>
  </div>
  ```

- [ ] Commit :
  ```bash
  git add app/views/student/conversations/_drawer.html.erb
  git commit -m "feat(tutor): add conversation drawer partial"
  ```

---

## Task 8 — Intégrer le drawer dans la page question et ajouter le bouton d'ouverture

La page question (`app/views/student/questions/show.html.erb`) utilise actuellement `data-controller="sidebar chat"` et rend `student/questions/chat_drawer`. Ces références doivent être mises à jour pour utiliser les nouveaux controllers.

**Files:**
- Modify: `app/views/student/questions/show.html.erb`
- Modify: `app/controllers/student/questions_controller.rb` (ajout `@conversation`)
- Commit: `feat(tutor): wire drawer into question show page with new controllers`

### Steps

- [ ] Vérifier que `@conversation` est déjà assigné dans `Student::QuestionsController#show`. Ouvrir `app/controllers/student/questions_controller.rb` et confirmer la ligne :
  ```ruby
  @conversation = current_student.conversations.find_by(question: @question)
  ```
  **Note :** Après Vague 1, la relation `Conversation` est par `(student, subject)`, plus par `question`. Mettre à jour cette ligne pour :
  ```ruby
  @conversation = current_student.conversations.find_by(subject: @subject)
  ```

- [ ] Dans `app/views/student/questions/show.html.erb`, localiser la ligne :
  ```erb
  <div data-controller="sidebar chat"
  ```
  La remplacer par :
  ```erb
  <div data-controller="sidebar chat-drawer"
  ```

  Supprimer les `data-chat-*` values obsolètes :
  ```
  data-chat-create-url-value
  data-chat-message-url-value
  data-chat-question-id-value
  data-chat-has-api-key-value
  data-chat-settings-url-value
  data-chat-conversation-id-value
  ```
  Elles ne sont plus utilisées par `chat-drawer`.

- [ ] Mettre à jour les deux boutons "Tutorat" (desktop + mobile) pour utiliser le nouveau controller :
  ```erb
  data-action="click->chat-drawer#open"
  ```
  (au lieu de `click->chat#open`)

  Supprimer `data-chat-target="toggle"` sur ces boutons. À la place, ajouter l'attribut de toggle :
  ```erb
  data-chat-drawer-toggle="true"
  aria-expanded="false"
  aria-controls="tutor-chat-drawer"
  ```

- [ ] Remplacer le rendu du drawer en fin de fichier :
  ```erb
  <%# Était : %>
  <%= render "student/questions/chat_drawer", conversation: @conversation %>

  <%# Devient : %>
  <%= render "student/conversations/drawer",
      conversation: @conversation,
      question: @question,
      access_code: params[:access_code] %>
  ```

- [ ] Commit :
  ```bash
  git add app/views/student/questions/show.html.erb \
          app/controllers/student/questions_controller.rb
  git commit -m "feat(tutor): wire drawer into question show page with new controllers"
  ```

---

## Task 9 — Bouton "Activer le tuteur" et action `conversations#create` Turbo Stream

Le bouton d'activation depuis la page sujet (`student/subjects/show.html.erb`) doit créer une conversation et ouvrir le drawer. Dans la nouvelle architecture, cela implique :
1. `POST /conversations` → crée la conversation, l'active (`conversation.activate!`), retourne un Turbo Stream.
2. Le Turbo Stream injecte le drawer (ou met à jour ses data-values) et déclenche l'ouverture.

Cependant, le drawer est déjà rendu sur la page question (pas sur la page sujet). L'activation depuis la page sujet redirige simplement vers la première question — le drawer s'ouvrira au chargement de la page question (via `auto_open` param ou via l'état `active` de la conversation).

**Files:**
- Modify: `app/controllers/student/conversations_controller.rb`
- Modify: `app/views/student/tutor/_tutor_banner.html.erb`
- Modify: `app/views/student/subjects/show.html.erb`
- Commit: `feat(tutor): add tutor activation button on subject page`

### Steps

- [ ] Écrire les specs request pour la nouvelle logique de `create`. Dans `spec/requests/student/conversations_spec.rb`, remplacer (ou enrichir) le bloc `describe "POST /conversations"` :

  ```ruby
  describe "POST /conversations" do
    context "avec une clé API" do
      it "crée une conversation active pour le sujet et retourne un Turbo Stream" do
        post student_conversations_path(access_code: classroom.access_code),
             params: { subject_id: subject_record.id },
             headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include("turbo-stream")

        conv = Conversation.find_by(student: student, subject: subject_record)
        expect(conv).to be_present
        expect(conv.lifecycle_state).to eq("active")
      end

      it "retourne la conversation existante si elle est déjà active" do
        existing = create(:conversation,
          student: student, subject: subject_record,
          lifecycle_state: "active")

        post student_conversations_path(access_code: classroom.access_code),
             params: { subject_id: subject_record.id },
             headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(response).to have_http_status(:ok)
        expect(Conversation.count).to eq(1)
      end

      it "rejette quand student n'a pas de clé API" do
        student.update!(api_key: nil)

        post student_conversations_path(access_code: classroom.access_code),
             params: { subject_id: subject_record.id },
             headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
  ```

- [ ] Confirmer l'échec :
  ```bash
  bundle exec rspec spec/requests/student/conversations_spec.rb \
    --format documentation 2>&1 | tail -10
  ```

- [ ] Mettre à jour `app/controllers/student/conversations_controller.rb`, action `create` :

  ```ruby
  def create
    @subject = @classroom.subjects.published.find(params[:subject_id])

    @conversation = current_student.conversations.find_or_initialize_by(subject: @subject)

    unless @conversation.persisted?
      @conversation.save!
    end

    @conversation.activate! unless @conversation.active?

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "tutor-activation-banner",
          partial: "student/tutor/tutor_activated",
          locals: {
            subject:     @subject,
            conversation: @conversation,
            access_code: params[:access_code]
          }
        )
      end
      format.json do
        render json: { conversation_id: @conversation.id }
      end
    end
  end
  ```

  Mettre à jour aussi `before_action :require_api_key` pour cibler correctement les actions :
  ```ruby
  before_action :require_api_key, only: [ :create, :message ]
  ```

- [ ] Créer `app/views/student/tutor/_tutor_activated.html.erb` (confirmation après activation) :

  ```erb
  <%# app/views/student/tutor/_tutor_activated.html.erb %>
  <div id="tutor-activation-banner"
       class="bg-indigo-50 dark:bg-indigo-900/20 border border-indigo-200 dark:border-indigo-500/30 rounded-lg p-4 mb-6">
    <div class="flex items-center gap-3">
      <span class="text-indigo-600 dark:text-indigo-400 text-lg">✓</span>
      <div>
        <p class="text-sm font-semibold text-indigo-800 dark:text-indigo-200">
          Mode tuteur activé
        </p>
        <p class="text-xs text-indigo-700 dark:text-indigo-300 mt-0.5">
          Le tuteur vous accompagnera dès la première question.
        </p>
      </div>
      <%= link_to "Commencer",
          student_question_path(
            access_code: access_code,
            subject_id: subject.id,
            id: subject.parts.order(:position).first&.questions&.kept&.order(:position)&.first&.id
          ),
          class: "ml-auto inline-flex items-center px-4 py-2 bg-indigo-600 text-white text-sm font-semibold rounded-lg hover:bg-indigo-700 transition-colors" %>
    </div>
  </div>
  ```

- [ ] Mettre à jour `app/views/student/tutor/_tutor_banner.html.erb` pour ajouter l'`id` du turbo-frame cible et utiliser `subject_id` dans le POST :

  ```erb
  <%# app/views/student/tutor/_tutor_banner.html.erb %>
  <div id="tutor-activation-banner"
       class="bg-indigo-50 dark:bg-indigo-900/20 border border-indigo-200 dark:border-indigo-500/30 rounded-lg p-5 mb-6">
    <div class="flex items-start gap-4">
      <div class="flex-shrink-0 text-indigo-500 dark:text-indigo-400 mt-0.5">
        <svg xmlns="http://www.w3.org/2000/svg" class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.346.346a1 1 0 01-.707.293H9.89a1 1 0 01-.707-.293l-.346-.346z" />
        </svg>
      </div>
      <div class="flex-1 min-w-0">
        <p class="text-sm font-semibold text-indigo-800 dark:text-indigo-200 mb-1">Mode tuteur disponible</p>
        <p class="text-sm text-indigo-700 dark:text-indigo-300">
          Activez le mode tuteur pour être guidé question par question par un assistant IA bienveillant.
          Le tuteur ne donne jamais les réponses — il vous aide à raisonner.
        </p>
      </div>
      <div class="flex-shrink-0">
        <%= button_to student_conversations_path(access_code: access_code),
                      method: :post,
                      params: { subject_id: subject.id },
                      data: { turbo_stream: true },
                      class: "inline-flex items-center px-4 py-2 bg-indigo-600 text-white text-sm font-semibold rounded-lg hover:bg-indigo-700 transition-colors cursor-pointer" do %>
          Activer le tuteur
        <% end %>
      </div>
    </div>
  </div>
  ```

- [ ] Vérifier que la condition dans `subjects/show.html.erb` couvre le cas `tutor_free_mode_enabled` ou clé API :

  Localiser dans `app/views/student/subjects/show.html.erb` :
  ```erb
  <% if @session_record.autonomous? && current_student.api_key.present? %>
  ```
  Remplacer par :
  ```erb
  <% if @session_record.autonomous? && (current_student.api_key.present? || @classroom.tutor_free_mode_enabled?) %>
  ```

- [ ] Lancer les specs :
  ```bash
  bundle exec rspec spec/requests/student/conversations_spec.rb --format documentation 2>&1 | tail -15
  ```
  Résultat attendu : `0 failures`.

- [ ] Commit :
  ```bash
  git add app/controllers/student/conversations_controller.rb \
          app/views/student/tutor/_tutor_banner.html.erb \
          app/views/student/tutor/_tutor_activated.html.erb \
          app/views/student/subjects/show.html.erb \
          spec/requests/student/conversations_spec.rb
  git commit -m "feat(tutor): add tutor activation button on subject page"
  ```

---

## Task 10 — Supprimer le vieux `chat_controller.js` et `_chat_drawer.html.erb`

Ces fichiers existaient dans le codebase pré-Vague-1. Si Vague 1 ne les a pas supprimés, les supprimer ici pour éviter tout conflit de nommage Stimulus.

**Files:**
- Delete: `app/javascript/controllers/chat_controller.js` (si encore présent)
- Delete: `app/views/student/questions/_chat_drawer.html.erb` (si encore présent)
- Commit: `refactor(tutor): remove legacy chat_controller and _chat_drawer partial`

### Steps

- [ ] Vérifier la présence des fichiers obsolètes :
  ```bash
  ls /home/fz/Documents/Dev/claudeCLI/DekatjeBakLa/app/javascript/controllers/chat_controller.js 2>/dev/null && echo "EXISTS" || echo "ABSENT"
  ls /home/fz/Documents/Dev/claudeCLI/DekatjeBakLa/app/views/student/questions/_chat_drawer.html.erb 2>/dev/null && echo "EXISTS" || echo "ABSENT"
  ```

- [ ] Si présents, supprimer :
  ```bash
  rm -f app/javascript/controllers/chat_controller.js
  rm -f app/views/student/questions/_chat_drawer.html.erb
  ```

- [ ] Vérifier qu'aucun fichier ne référence encore `chat_controller` ou `chat_drawer` (hors le nouveau `tutor-chat-drawer`) :
  ```bash
  grep -r "chat_controller\|chat_drawer\|->chat#" \
    app/views app/javascript \
    --include="*.erb" --include="*.js" --include="*.html"
  ```
  Résultat attendu : aucune ligne, ou uniquement des références au nouveau `chat-drawer`.

- [ ] Lancer la suite de tests non-JS pour s'assurer qu'aucune référence manquante :
  ```bash
  bundle exec rspec --exclude-pattern "**/*_spec.rb" \
    spec/requests spec/models spec/services 2>&1 | tail -5
  ```
  Résultat attendu : `0 failures`.

- [ ] Commit :
  ```bash
  git add -u
  git commit -m "refactor(tutor): remove legacy chat_controller and _chat_drawer partial"
  ```

---

## Task 11 — Spec E2E feature : `spec/features/student_tutor_chat_spec.rb`

C'est le test de validation finale de la Vague 4. Il remplace le fichier `xdescribe` existant par un vrai `RSpec.describe` avec des scenarios Capybara.

**Files:**
- Replace: `spec/features/student_tutor_chat_spec.rb`
- Commit: `test(tutor): add E2E feature spec for Vague 4 Hotwire chat UI`

### Steps

- [ ] Vérifier que FakeRubyLlm est disponible (créé en Vague 2) :
  ```bash
  ls /home/fz/Documents/Dev/claudeCLI/DekatjeBakLa/spec/support/fake_ruby_llm.rb 2>/dev/null && echo "OK" || echo "MISSING"
  ```
  Si absent, créer un stub minimal qui permet à `AiClientFactory` de retourner une réponse synchrone en test :

  ```ruby
  # spec/support/fake_ruby_llm.rb
  module FakeRubyLlm
    def self.setup_stub(response: "Voici une aide.")
      client_double = instance_double("Object")
      allow(AiClientFactory).to receive(:build).and_return(client_double)
      allow(client_double).to receive(:stream) do |**, &block|
        response.chars.each_slice(3) { |chunk| block.call(chunk.join) }
      end
    end
  end

  RSpec.configure do |config|
    config.include FakeRubyLlm, type: :feature
  end
  ```

- [ ] Lancer le spec existant (xdescribe) en dry-run pour confirmer qu'il est pending :
  ```bash
  bundle exec rspec spec/features/student_tutor_chat_spec.rb --dry-run 2>&1 | tail -5
  ```

- [ ] Écrire le nouveau spec E2E. **Remplacer entièrement** `spec/features/student_tutor_chat_spec.rb` :

  ```ruby
  # spec/features/student_tutor_chat_spec.rb
  require "rails_helper"

  RSpec.describe "Vague 4 — Interface Hotwire du tuteur", type: :feature do
    let(:teacher)   { create(:user) }
    let(:classroom) { create(:classroom, name: "Terminale SIN 2026", owner: teacher) }
    let(:student) do
      create(:student, classroom: classroom, api_key: "sk-test", api_provider: :anthropic)
    end
    let(:subject_record) do
      create(:subject,
        status: :published,
        owner:  teacher,
        specific_presentation: "La société CIME fabrique des véhicules électriques.")
    end
    let(:part) do
      create(:part, :specific,
        subject:        subject_record,
        number:         1,
        title:          "Transport et développement durable",
        objective_text: "Comparer les modes de transport.",
        position:       1)
    end
    let!(:question) do
      create(:question,
        part:     part,
        number:   "1.1",
        label:    "Calculer la consommation en litres pour 186 km.",
        points:   2,
        position: 1)
    end
    let!(:answer) do
      create(:answer,
        question:         question,
        correction_text:  "Car = 56,73 l",
        explanation_text: "Formule Consommation x Distance / 100")
    end
    let!(:classroom_subject) do
      create(:classroom_subject, classroom: classroom, subject: subject_record)
    end

    def visit_question_page
      visit student_question_path(
        access_code: classroom.access_code,
        subject_id:  subject_record.id,
        id:          question.id
      )
    end

    def open_drawer
      # Le bouton est présent dans le bottom bar (mobile) et dans la barre desktop
      # En Capybara headless, cliquer le premier "Tutorat" trouvé
      first("[data-action*='chat-drawer#open']", visible: true).click
      expect(page).to have_css("#tutor-chat-drawer:not(.translate-x-full)", wait: 5)
    end

    # -----------------------------------------------------------------------
    # Scenario 1 : Bouton "Activer le tuteur" visible sur la page sujet
    # -----------------------------------------------------------------------
    scenario "l'élève avec clé API voit le bouton 'Activer le tuteur' sur la page sujet", js: true do
      login_as_student(student, classroom)

      # S'assurer qu'il n'y a pas de session tuteur => banner visible
      visit student_subject_path(
        access_code: classroom.access_code,
        id:          subject_record.id
      )

      expect(page).to have_button("Activer le tuteur")
    end

    # -----------------------------------------------------------------------
    # Scenario 2 : Activation du tuteur — drawer s'ouvre avec message d'accueil
    # -----------------------------------------------------------------------
    scenario "activer le tuteur crée la conversation et affiche une confirmation", js: true do
      FakeRubyLlm.setup_stub(response: "Bonjour ! Je suis votre tuteur.")

      login_as_student(student, classroom)
      visit student_subject_path(
        access_code: classroom.access_code,
        id:          subject_record.id
      )

      click_button "Activer le tuteur"

      # La bannière doit être remplacée par la confirmation
      expect(page).to have_text("Mode tuteur activé", wait: 5)
      expect(page).not_to have_button("Activer le tuteur")
    end

    # -----------------------------------------------------------------------
    # Scenario 3 : Envoyer un message — apparition optimiste + réponse streaming
    # -----------------------------------------------------------------------
    scenario "l'élève envoie un message et la réponse arrive en streaming", js: true do
      FakeRubyLlm.setup_stub(response: "Bonne question ! As-tu regardé le DT1 ?")

      # Pré-créer une conversation active
      create(:conversation,
        student:         student,
        subject:         subject_record,
        lifecycle_state: "active")

      login_as_student(student, classroom)
      visit_question_page

      open_drawer

      # Saisir et envoyer un message
      input = find("[data-tutor-chat-target='input']", visible: true)
      input.fill_in(with: "Comment calculer la consommation ?")
      find("[data-tutor-chat-target='sendButton']", visible: true).click

      # Le message optimiste apparaît immédiatement
      within("#tutor-chat-drawer") do
        expect(page).to have_text("Comment calculer la consommation ?", wait: 3)
      end

      # L'input est désactivé pendant le streaming
      expect(page).to have_css("[data-tutor-chat-target='input'][disabled]", wait: 3)

      # La réponse du tuteur arrive via ActionCable (simulée par FakeRubyLlm)
      within("#tutor-chat-drawer") do
        expect(page).to have_text("Bonne question !", wait: 10)
      end

      # L'input est réactivé
      expect(page).not_to have_css("[data-tutor-chat-target='input'][disabled]", wait: 5)
    end

    # -----------------------------------------------------------------------
    # Scenario 4 : Phase :validating — boutons de confiance apparaissent dans le chat
    # -----------------------------------------------------------------------
    scenario "en phase validating les boutons de confiance sont visibles dans le chat", js: true do
      # Créer une conversation en phase validating avec un message qui contient le formulaire
      conversation = create(:conversation,
        student:         student,
        subject:         subject_record,
        lifecycle_state: "validating",
        tutor_state: TutorState.new(
          current_phase:        "validating",
          current_question_id:  question.id,
          concepts_mastered:    [],
          concepts_to_revise:   [],
          discouragement_level: 0,
          question_states:      {
            question.id.to_s => QuestionState.new(
              step: "initial", hints_used: 0, last_confidence: nil,
              error_types: [], completed_at: nil
            )
          }
        )
      )

      # Ajouter un message assistant + le formulaire de confiance
      create(:message,
        conversation: conversation,
        role: :assistant,
        content: "Très bien ! Maintenant, évalue ta confiance.")

      login_as_student(student, classroom)
      visit_question_page

      open_drawer

      within("#tutor-chat-drawer") do
        expect(page).to have_text("Très bien !", wait: 5)
        # Le formulaire de confiance est rendu dans le drawer
        (1..5).each { |n| expect(page).to have_button(n.to_s) }
      end
    end

    # -----------------------------------------------------------------------
    # Scenario 5 : Cliquer sur confiance 3 — boutons disparaissent, transition vers feedback
    # -----------------------------------------------------------------------
    scenario "sélectionner confiance 3 remplace le formulaire par la confirmation", js: true do
      FakeRubyLlm.setup_stub(response: "")

      conversation = create(:conversation,
        student:         student,
        subject:         subject_record,
        lifecycle_state: "validating",
        tutor_state: TutorState.new(
          current_phase:        "validating",
          current_question_id:  question.id,
          concepts_mastered:    [],
          concepts_to_revise:   [],
          discouragement_level: 0,
          question_states:      {
            question.id.to_s => QuestionState.new(
              step: "initial", hints_used: 0, last_confidence: nil,
              error_types: [], completed_at: nil
            )
          }
        )
      )

      create(:message,
        conversation: conversation,
        role: :assistant,
        content: "Évalue ta confiance.")

      login_as_student(student, classroom)
      visit_question_page

      open_drawer

      within("#tutor-chat-drawer") do
        # Trouver le bouton confiance "3" dans le formulaire
        confidence_frame = find("[id^='confidence-form-']", wait: 5)
        within(confidence_frame) do
          click_button "3"
        end

        # Le formulaire est remplacé par la confirmation
        expect(page).to have_text("Confiance enregistrée", wait: 5)
        expect(page).not_to have_css("[data-confidence-form-target='button']")
      end
    end

    # -----------------------------------------------------------------------
    # Scenario 6 : Fermer et rouvrir le drawer sans perdre les messages
    # -----------------------------------------------------------------------
    scenario "fermer et rouvrir le drawer conserve les messages", js: true do
      conversation = create(:conversation,
        student:         student,
        subject:         subject_record,
        lifecycle_state: "active")
      create(:message,
        conversation: conversation,
        role: :user,
        content: "Message déjà envoyé")
      create(:message,
        conversation: conversation,
        role: :assistant,
        content: "Réponse déjà reçue")

      login_as_student(student, classroom)
      visit_question_page

      open_drawer

      within("#tutor-chat-drawer") do
        expect(page).to have_text("Message déjà envoyé", wait: 3)
        expect(page).to have_text("Réponse déjà reçue")
      end

      # Fermer
      within("#tutor-chat-drawer") do
        find("button[aria-label='Fermer le tutorat']").click
      end
      expect(page).to have_css("#tutor-chat-drawer.translate-x-full", wait: 3)

      # Rouvrir
      open_drawer

      within("#tutor-chat-drawer") do
        expect(page).to have_text("Message déjà envoyé", wait: 3)
        expect(page).to have_text("Réponse déjà reçue")
      end
    end
  end
  ```

- [ ] Lancer les specs pour confirmer les échecs initiaux (avant d'avoir tout le code en place) :
  ```bash
  bundle exec rspec spec/features/student_tutor_chat_spec.rb --format documentation 2>&1 | tail -20
  ```
  Résultat attendu : certains scénarios passent, d'autres échouent selon l'état d'avancement.

- [ ] Une fois toutes les tâches précédentes complètes, lancer le spec complet et confirmer que **tous les scénarios passent** :
  ```bash
  bundle exec rspec spec/features/student_tutor_chat_spec.rb --format documentation 2>&1 | tail -20
  ```
  Résultat attendu : `6 examples, 0 failures`.

- [ ] Lancer la suite complète pour s'assurer d'aucune régression :
  ```bash
  bundle exec rspec --format progress 2>&1 | tail -10
  ```
  Résultat attendu : `0 failures`.

- [ ] Commit :
  ```bash
  git add spec/features/student_tutor_chat_spec.rb spec/support/fake_ruby_llm.rb
  git commit -m "test(tutor): add E2E feature spec for Vague 4 Hotwire chat UI"
  ```

---

## Récapitulatif des fichiers créés / modifiés

| Fichier | Action |
|---|---|
| `app/jobs/tutor_stream_job.rb` | Modifier — messages typés `{ type: }` |
| `app/controllers/student/conversations_controller.rb` | Modifier — actions `create` (Turbo Stream) + `confidence` |
| `config/routes.rb` | Modifier — ajouter `patch :confidence` |
| `app/views/student/conversations/_message.html.erb` | Créer — rendu d'un `Message` |
| `app/views/student/conversations/_confidence_form.html.erb` | Créer — formulaire 1-5 |
| `app/views/student/conversations/_drawer.html.erb` | Créer — drawer complet |
| `app/views/student/conversations/confidence.turbo_stream.erb` | Créer — Turbo Stream réponse confiance |
| `app/views/student/tutor/_tutor_banner.html.erb` | Modifier — POST vers `conversations#create` |
| `app/views/student/tutor/_tutor_activated.html.erb` | Créer — confirmation post-activation |
| `app/views/student/subjects/show.html.erb` | Modifier — condition `tutor_free_mode_enabled` |
| `app/views/student/questions/show.html.erb` | Modifier — `chat-drawer` controller, nouveau drawer partial |
| `app/controllers/student/questions_controller.rb` | Modifier — `@conversation` par sujet |
| `app/javascript/controllers/chat_drawer_controller.js` | Créer |
| `app/javascript/controllers/tutor_chat_controller.js` | Créer |
| `app/javascript/controllers/confidence_form_controller.js` | Créer |
| `app/javascript/controllers/chat_controller.js` | Supprimer (legacy) |
| `app/views/student/questions/_chat_drawer.html.erb` | Supprimer (legacy) |
| `spec/jobs/tutor_stream_job_spec.rb` | Remplacer `xdescribe` → `describe`, adapter |
| `spec/requests/student/conversations_spec.rb` | Étendre — confidence + activation |
| `spec/features/student_tutor_chat_spec.rb` | Remplacer — 6 scénarios Capybara Vague 4 |
| `spec/support/fake_ruby_llm.rb` | Créer si absent |

## Ordre des commits

1. `feat(tutor): broadcast typed messages (token/done/error) from TutorStreamJob`
2. `feat(tutor): add message partial for conversation rendering`
3. `feat(tutor): add confidence form partial and Stimulus controller`
4. `feat(tutor): add PATCH conversations#confidence endpoint`
5. `feat(tutor): add chat-drawer Stimulus controller (open/close drawer)`
6. `feat(tutor): add tutor-chat Stimulus controller (messaging + ActionCable streaming)`
7. `feat(tutor): add conversation drawer partial`
8. `feat(tutor): wire drawer into question show page with new controllers`
9. `feat(tutor): add tutor activation button on subject page`
10. `refactor(tutor): remove legacy chat_controller and _chat_drawer partial`
11. `test(tutor): add E2E feature spec for Vague 4 Hotwire chat UI`
