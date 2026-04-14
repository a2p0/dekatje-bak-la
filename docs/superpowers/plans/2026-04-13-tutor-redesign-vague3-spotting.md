# Vague 3 — Phase de repérage : Plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implémenter la phase de repérage : prompt spécifique spotting injecté dans `BuildContext`, filtre regex post-LLM (`FilterSpottingOutput`), injection serveur des data_hints (`InjectDataHints`), composant `DataHintsComponent`, et spec E2E Capybara de la phase complète.

**Architecture:** Extension du pipeline existant (Vague 2). `FilterSpottingOutput` s'insère entre `CallLlm` et `ParseToolCalls` dans `ProcessMessage`. `InjectDataHints` s'exécute après `ApplyToolCalls` si l'outil `evaluate_spotting` retourne un outcome terminal (`success` ou `forced_reveal`). Les data_hints sont toujours construits côté serveur à partir de `Answer#data_hints`, jamais générés par le LLM.

**Tech Stack:** Rails 8, ViewComponent, FakeRubyLlm (RSpec stubs), Capybara

**Prérequis Vague 2 accomplie :**
- `Tutor::Result` struct disponible
- `Tutor::BuildContext` service avec `SYSTEM_TEMPLATE`
- `Tutor::CallLlm` service retournant `{ full_content:, tool_calls: }`
- `Tutor::ParseToolCalls` service
- `Tutor::ApplyToolCalls` service avec `evaluate_spotting` tool
- `Tutor::UpdateTutorState`, `Tutor::BroadcastMessage` services
- `Tutor::ProcessMessage` pipeline orchestrateur
- `Message` model (table `messages`, colonnes `role`, `content`, `conversation_id`, `chunk_index`, `streaming_finished_at`)
- `spec/support/fake_ruby_llm.rb` avec `FakeRubyLlm.setup_stub`

---

## Task 1 — Spotting prompt section dans `BuildContext`

**Files:**
- Modify: `app/services/tutor/build_context.rb`
- Modify: `spec/services/tutor/build_context_spec.rb`
- Commit: `feat(tutor): inject spotting phase rules into BuildContext system prompt`

### Steps

- [ ] Add failing examples to `spec/services/tutor/build_context_spec.rb`. Append a new `context "en phase spotting"` block inside the top-level `describe Tutor::BuildContext`:
  ```ruby
  context "en phase spotting" do
    let(:spotting_conversation) do
      spotting_state = TutorState.new(
        current_phase:        "spotting",
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
      create(:conversation, student: student, subject: exam_subject,
             lifecycle_state: "active", tutor_state: spotting_state)
    end

    subject(:result) do
      described_class.call(
        conversation:  spotting_conversation,
        question:      question,
        student_input: "Je pense que c'est dans l'énoncé."
      )
    end

    it "includes the spotting phase header" do
      expect(result.value[:system_prompt]).to include("PHASE REPÉRAGE")
    end

    it "includes the 3-level relaunch instructions" do
      expect(result.value[:system_prompt]).to include("Niveau 1")
      expect(result.value[:system_prompt]).to include("Niveau 2")
      expect(result.value[:system_prompt]).to include("Niveau 3")
    end

    it "includes the forbidden patterns warning" do
      expect(result.value[:system_prompt]).to include("INTERDIT ABSOLU")
      expect(result.value[:system_prompt]).to include("Mentionner des noms précis de documents")
    end

    it "includes the forced_reveal instruction after 3 failed relaunches" do
      expect(result.value[:system_prompt]).to include("forced_reveal")
    end

    it "does NOT include the spotting section when phase is not spotting" do
      reading_state = TutorState.new(
        current_phase:        "reading",
        current_question_id:  nil,
        concepts_mastered:    [],
        concepts_to_revise:   [],
        discouragement_level: 0,
        question_states:      {}
      )
      reading_conv = create(:conversation, student: student, subject: exam_subject,
                             lifecycle_state: "active", tutor_state: reading_state)
      r = described_class.call(
        conversation:  reading_conv,
        question:      question,
        student_input: "test"
      )
      expect(r.value[:system_prompt]).not_to include("PHASE REPÉRAGE")
    end
  end
  ```

- [ ] Run only the new examples and confirm they fail:
  ```bash
  bundle exec rspec spec/services/tutor/build_context_spec.rb -e "en phase spotting" --format documentation 2>&1 | tail -15
  ```
  Expected: `5 examples, 5 failures` (constant or method missing).

- [ ] Add the `SPOTTING_SECTION` constant and the conditional injection inside `app/services/tutor/build_context.rb`. The section is appended to the system prompt when `conversation.tutor_state.current_phase == "spotting"`. Add after the `SYSTEM_TEMPLATE` constant:
  ```ruby
  SPOTTING_SECTION = <<~PROMPT.freeze

    [PHASE REPÉRAGE — RÈGLES SPÉCIFIQUES]
    L'élève doit identifier en langage libre où se trouvent les données utiles pour cette question.
    Tu évalues sa réponse via l'outil evaluate_spotting.

    Niveaux de relance progressifs :
    - Niveau 1 (première question) : question ouverte, ex. "Où penses-tu trouver les informations pour cette question ?"
    - Niveau 2 (si raté) : nature conceptuelle, ex. "Réfléchis au type de données dont tu as besoin : caractéristique du véhicule ? information sur le trajet ?"
    - Niveau 3 (si raté encore) : structure BAC, ex. "Dans un sujet BAC STI2D, les caractéristiques techniques sont regroupées dans une certaine catégorie de documents."

    INTERDIT ABSOLU pendant le repérage :
    - Mentionner des noms précis de documents (DT1, DT2, DR1, etc.)
    - Donner des valeurs chiffrées issues de la correction
    - Indiquer la localisation exacte dans les documents

    Après 3 relances échouées : utiliser outcome "forced_reveal" pour débloquer l'élève.
  PROMPT
  ```

  Modify the `call` method to append the section when in spotting phase. Replace:
  ```ruby
  Result.ok(system_prompt: system_prompt, messages: messages)
  ```
  with:
  ```ruby
  system_prompt += SPOTTING_SECTION if @conversation.tutor_state.current_phase == "spotting"
  Result.ok(system_prompt: system_prompt, messages: messages)
  ```

- [ ] Run the new examples again:
  ```bash
  bundle exec rspec spec/services/tutor/build_context_spec.rb -e "en phase spotting" --format documentation 2>&1 | tail -15
  ```
  Expected: `5 examples, 0 failures`.

- [ ] Run the full BuildContext spec to verify no regressions:
  ```bash
  bundle exec rspec spec/services/tutor/build_context_spec.rb --format documentation 2>&1 | tail -15
  ```
  Expected: 0 failures.

- [ ] Commit:
  ```bash
  git add app/services/tutor/build_context.rb spec/services/tutor/build_context_spec.rb
  git commit -m "feat(tutor): inject spotting phase rules into BuildContext system prompt"
  ```

---

## Task 2 — `Tutor::FilterSpottingOutput` service

**Files:**
- Create: `app/services/tutor/filter_spotting_output.rb`
- Create: `spec/services/tutor/filter_spotting_output_spec.rb`
- Commit: `feat(tutor): add Tutor::FilterSpottingOutput post-LLM regex filter`

### Steps

- [ ] Write the failing spec first:
  ```ruby
  # spec/services/tutor/filter_spotting_output_spec.rb
  require "rails_helper"

  RSpec.describe Tutor::FilterSpottingOutput do
    let(:user)         { create(:user) }
    let(:classroom)    { create(:classroom, owner: user) }
    let(:student)      { create(:student, classroom: classroom) }
    let(:exam_subject) { create(:subject, owner: user, status: :published) }
    let(:part)         { create(:part, subject: exam_subject) }
    let(:question)     { create(:question, part: part) }
    let(:conversation) do
      state = TutorState.new(
        current_phase:        "spotting",
        current_question_id:  question.id,
        concepts_mastered:    [],
        concepts_to_revise:   [],
        discouragement_level: 0,
        question_states:      {}
      )
      create(:conversation, student: student, subject: exam_subject,
             lifecycle_state: "active", tutor_state: state)
    end
    let(:assistant_msg) do
      create(:message, conversation: conversation, role: :assistant,
             content: "test content", chunk_index: 0)
    end

    describe ".call" do
      context "when phase is spotting and content is clean" do
        it "returns ok with unchanged content" do
          result = described_class.call(
            message:    assistant_msg,
            llm_output: "Où penses-tu trouver les informations ?"
          )
          expect(result.ok?).to be true
          expect(result.value[:filtered]).to be false
          expect(assistant_msg.reload.content).to eq("Où penses-tu trouver les informations ?")
        end
      end

      context "when content contains a DT reference" do
        it "returns ok with filtered: true and replaces content with neutral relaunch" do
          result = described_class.call(
            message:    assistant_msg,
            llm_output: "Les données se trouvent dans DT1, tableau page 3."
          )
          expect(result.ok?).to be true
          expect(result.value[:filtered]).to be true
          reloaded = assistant_msg.reload.content
          expect(reloaded).to eq(
            "Reformule ta réponse sans mentionner de documents spécifiques ni de valeurs chiffrées. Où penses-tu trouver les informations ?"
          )
          expect(reloaded).not_to include("DT1")
        end
      end

      context "when content contains a DR reference" do
        it "filters DR2 reference" do
          result = described_class.call(
            message:    assistant_msg,
            llm_output: "Regarde dans DR2 pour compléter."
          )
          expect(result.value[:filtered]).to be true
        end
      end

      context "when content contains a numeric value with unit" do
        it "filters values like '56,73 l'" do
          result = described_class.call(
            message:    assistant_msg,
            llm_output: "La consommation est de 56,73 l pour ce trajet."
          )
          expect(result.value[:filtered]).to be true
        end

        it "filters values like '186 km'" do
          result = described_class.call(
            message:    assistant_msg,
            llm_output: "La distance est 186 km."
          )
          expect(result.value[:filtered]).to be true
        end

        it "filters values like '19600 N'" do
          result = described_class.call(
            message:    assistant_msg,
            llm_output: "La force appliquée est 19600 N."
          )
          expect(result.value[:filtered]).to be true
        end
      end

      context "when phase is not spotting" do
        it "returns ok immediately without checking patterns" do
          guiding_state = TutorState.new(
            current_phase:        "guiding",
            current_question_id:  question.id,
            concepts_mastered:    [],
            concepts_to_revise:   [],
            discouragement_level: 0,
            question_states:      {}
          )
          guiding_conv = create(:conversation, student: student, subject: exam_subject,
                                lifecycle_state: "active", tutor_state: guiding_state)
          guiding_msg = create(:message, conversation: guiding_conv, role: :assistant,
                               content: "original", chunk_index: 0)

          result = described_class.call(
            message:    guiding_msg,
            llm_output: "Les données sont dans DT1, valeur 56,73 l."
          )
          expect(result.ok?).to be true
          expect(result.value[:filtered]).to be false
          # Content must NOT be overwritten when not in spotting phase
          expect(guiding_msg.reload.content).to eq("original")
        end
      end

      context "when message already has content" do
        it "persists the filtered neutral relaunch to message#content" do
          assistant_msg.update!(content: "Les données sont en DT2.")
          described_class.call(
            message:    assistant_msg,
            llm_output: "Les données sont en DT2."
          )
          expect(assistant_msg.reload.content).to eq(
            "Reformule ta réponse sans mentionner de documents spécifiques ni de valeurs chiffrées. Où penses-tu trouver les informations ?"
          )
        end
      end
    end
  end
  ```

- [ ] Run the spec and confirm failures:
  ```bash
  bundle exec rspec spec/services/tutor/filter_spotting_output_spec.rb --format documentation 2>&1 | tail -15
  ```
  Expected: `NameError: uninitialized constant Tutor::FilterSpottingOutput`.

- [ ] Create the service:
  ```ruby
  # app/services/tutor/filter_spotting_output.rb
  module Tutor
    class FilterSpottingOutput
      NEUTRAL_RELAUNCH = "Reformule ta réponse sans mentionner de documents spécifiques ni de valeurs chiffrées. Où penses-tu trouver les informations ?".freeze

      FORBIDDEN_PATTERNS = [
        /\bD[TR]\s*\d+\b/i,
        /\d+[,.]?\d*\s*(km|l|kWh|W|N|kg|m|s|h|min|%|€|°C)\b/i
      ].freeze

      def self.call(message:, llm_output:)
        new(message: message, llm_output: llm_output).call
      end

      def initialize(message:, llm_output:)
        @message    = message
        @llm_output = llm_output
      end

      def call
        unless in_spotting_phase?
          return Result.ok(filtered: false)
        end

        if forbidden?
          @message.update!(content: NEUTRAL_RELAUNCH)
          Result.ok(filtered: true)
        else
          @message.update!(content: @llm_output)
          Result.ok(filtered: false)
        end
      end

      private

      def in_spotting_phase?
        @message.conversation.tutor_state.current_phase == "spotting"
      end

      def forbidden?
        FORBIDDEN_PATTERNS.any? { |pattern| @llm_output.match?(pattern) }
      end
    end
  end
  ```

- [ ] Run the spec again:
  ```bash
  bundle exec rspec spec/services/tutor/filter_spotting_output_spec.rb --format documentation 2>&1 | tail -15
  ```
  Expected: `9 examples, 0 failures`.

- [ ] Commit:
  ```bash
  git add app/services/tutor/filter_spotting_output.rb spec/services/tutor/filter_spotting_output_spec.rb
  git commit -m "feat(tutor): add Tutor::FilterSpottingOutput post-LLM regex filter"
  ```

---

## Task 3 — `DataHintsComponent` ViewComponent

**Files:**
- Create: `app/components/data_hints_component.rb`
- Create: `app/components/data_hints_component.html.erb`
- Create: `spec/components/data_hints_component_spec.rb`
- Commit: `feat(tutor): add DataHintsComponent ViewComponent`

### Steps

- [ ] Write the failing spec first:
  ```ruby
  # spec/components/data_hints_component_spec.rb
  require "rails_helper"

  RSpec.describe DataHintsComponent, type: :component do
    let(:data_hints) do
      [
        { "source" => "DT1", "location" => "tableau, ligne Consommation moyenne" },
        { "source" => "mise_en_situation", "location" => "distances Troyes-Le Bourget" }
      ]
    end

    it "renders the section title" do
      render_inline(described_class.new(data_hints: data_hints))
      expect(page).to have_text("Les données nécessaires se trouvaient dans")
    end

    it "renders each source in bold" do
      render_inline(described_class.new(data_hints: data_hints))
      expect(page).to have_css("strong", text: "DT1")
      expect(page).to have_css("strong", text: "mise_en_situation")
    end

    it "renders each location" do
      render_inline(described_class.new(data_hints: data_hints))
      expect(page).to have_text("tableau, ligne Consommation moyenne")
      expect(page).to have_text("distances Troyes-Le Bourget")
    end

    it "renders as a list" do
      render_inline(described_class.new(data_hints: data_hints))
      expect(page).to have_css("ul li", count: 2)
    end

    it "wraps everything in a .data-hints-card div" do
      render_inline(described_class.new(data_hints: data_hints))
      expect(page).to have_css("div.data-hints-card")
    end

    it "renders nothing when data_hints is empty" do
      render_inline(described_class.new(data_hints: []))
      expect(page).not_to have_text("Les données nécessaires")
    end
  end
  ```

- [ ] Run the spec and confirm failures:
  ```bash
  bundle exec rspec spec/components/data_hints_component_spec.rb --format documentation 2>&1 | tail -15
  ```
  Expected: `NameError: uninitialized constant DataHintsComponent`.

- [ ] Create the component class:
  ```ruby
  # app/components/data_hints_component.rb
  class DataHintsComponent < ViewComponent::Base
    def initialize(data_hints:)
      @data_hints = data_hints
    end

    def render?
      @data_hints.any?
    end
  end
  ```

- [ ] Create the component template:
  ```erb
  <%# app/components/data_hints_component.html.erb %>
  <div class="data-hints-card rounded-lg border border-amber-200 bg-amber-50 p-4 dark:border-amber-800 dark:bg-amber-950/30">
    <p class="mb-2 text-sm font-semibold text-amber-800 dark:text-amber-300">
      Les données nécessaires se trouvaient dans :
    </p>
    <ul class="space-y-1 text-sm text-amber-900 dark:text-amber-200">
      <% @data_hints.each do |hint| %>
        <li>
          <strong><%= hint["source"] %></strong>
          &mdash;
          <%= hint["location"] %>
        </li>
      <% end %>
    </ul>
  </div>
  ```

- [ ] Run the spec again:
  ```bash
  bundle exec rspec spec/components/data_hints_component_spec.rb --format documentation 2>&1 | tail -15
  ```
  Expected: `6 examples, 0 failures`.

- [ ] Commit:
  ```bash
  git add app/components/data_hints_component.rb app/components/data_hints_component.html.erb spec/components/data_hints_component_spec.rb
  git commit -m "feat(tutor): add DataHintsComponent ViewComponent"
  ```

---

## Task 4 — `Tutor::InjectDataHints` service

**Files:**
- Create: `app/services/tutor/inject_data_hints.rb`
- Create: `spec/services/tutor/inject_data_hints_spec.rb`
- Commit: `feat(tutor): add Tutor::InjectDataHints service`

### Steps

- [ ] Write the failing spec first:
  ```ruby
  # spec/services/tutor/inject_data_hints_spec.rb
  require "rails_helper"

  RSpec.describe Tutor::InjectDataHints do
    let(:user)      { create(:user) }
    let(:classroom) { create(:classroom, owner: user) }
    let(:student)      { create(:student, classroom: classroom) }
    let(:exam_subject) { create(:subject, owner: user, status: :published) }
    let(:part)         { create(:part, subject: exam_subject) }
    let(:question)     { create(:question, part: part) }
    let!(:answer) do
      create(:answer, question: question,
        correction_text: "Car = 56,73 l",
        data_hints: [
          { "source" => "DT1", "location" => "tableau Consommation moyenne" },
          { "source" => "mise_en_situation", "location" => "distance 186 km" }
        ])
    end
    let(:conversation) do
      create(:conversation, student: student, subject: exam_subject,
             lifecycle_state: "active")
    end

    shared_examples "injects data_hints" do |outcome_value|
      it "creates a system Message with the rendered data_hints" do
        described_class.call(
          conversation: conversation,
          question:     question,
          outcome:      outcome_value
        )
        system_msg = conversation.messages.reload.find { |m| m.role == "system" }
        expect(system_msg).to be_present
        expect(system_msg.content).to include("DT1")
        expect(system_msg.content).to include("tableau Consommation moyenne")
        expect(system_msg.content).to include("mise_en_situation")
      end

      it "broadcasts to the conversation channel with type data_hints" do
        expect(ActionCable.server).to receive(:broadcast).with(
          "conversation_#{conversation.id}",
          hash_including(type: "data_hints")
        )
        described_class.call(
          conversation: conversation,
          question:     question,
          outcome:      outcome_value
        )
      end

      it "returns ok" do
        result = described_class.call(
          conversation: conversation,
          question:     question,
          outcome:      outcome_value
        )
        expect(result.ok?).to be true
      end
    end

    context "with outcome 'success'" do
      include_examples "injects data_hints", "success"
    end

    context "with outcome 'forced_reveal'" do
      include_examples "injects data_hints", "forced_reveal"
    end

    context "with outcome 'relaunch' (non-terminal)" do
      it "does not create any message" do
        expect {
          described_class.call(
            conversation: conversation,
            question:     question,
            outcome:      "relaunch"
          )
        }.not_to change { conversation.messages.count }
      end

      it "returns ok without side effects" do
        result = described_class.call(
          conversation: conversation,
          question:     question,
          outcome:      "relaunch"
        )
        expect(result.ok?).to be true
      end
    end

    context "when answer has no data_hints" do
      before { answer.update!(data_hints: []) }

      it "does not create any message even on success outcome" do
        expect {
          described_class.call(
            conversation: conversation,
            question:     question,
            outcome:      "success"
          )
        }.not_to change { conversation.messages.count }
      end
    end
  end
  ```

- [ ] Run the spec and confirm failures:
  ```bash
  bundle exec rspec spec/services/tutor/inject_data_hints_spec.rb --format documentation 2>&1 | tail -15
  ```
  Expected: `NameError: uninitialized constant Tutor::InjectDataHints`.

- [ ] Create the service:
  ```ruby
  # app/services/tutor/inject_data_hints.rb
  module Tutor
    class InjectDataHints
      TERMINAL_OUTCOMES = %w[success forced_reveal].freeze

      def self.call(conversation:, question:, outcome:)
        new(conversation: conversation, question: question, outcome: outcome).call
      end

      def initialize(conversation:, question:, outcome:)
        @conversation = conversation
        @question     = question
        @outcome      = outcome
      end

      def call
        return Result.ok unless terminal_outcome?

        hints = @question.answer&.data_hints.to_a
        return Result.ok if hints.empty?

        rendered = render_data_hints(hints)
        msg = @conversation.messages.create!(
          role:    :system,
          content: rendered,
          chunk_index: 0
        )

        ActionCable.server.broadcast(
          "conversation_#{@conversation.id}",
          {
            type:       "data_hints",
            message_id: msg.id,
            html:       rendered
          }
        )

        Result.ok
      end

      private

      def terminal_outcome?
        TERMINAL_OUTCOMES.include?(@outcome.to_s)
      end

      def render_data_hints(hints)
        ApplicationController.render(
          DataHintsComponent.new(data_hints: hints),
          layout: false
        )
      end
    end
  end
  ```

- [ ] Run the spec again:
  ```bash
  bundle exec rspec spec/services/tutor/inject_data_hints_spec.rb --format documentation 2>&1 | tail -15
  ```
  Expected: `8 examples, 0 failures`.

- [ ] Commit:
  ```bash
  git add app/services/tutor/inject_data_hints.rb spec/services/tutor/inject_data_hints_spec.rb
  git commit -m "feat(tutor): add Tutor::InjectDataHints service"
  ```

---

## Task 5 — Intégration dans `Tutor::ProcessMessage`

**Files:**
- Modify: `app/services/tutor/process_message.rb`
- Modify: `spec/services/tutor/process_message_spec.rb`
- Commit: `feat(tutor): wire FilterSpottingOutput and InjectDataHints into ProcessMessage`

### Steps

- [ ] Add failing examples to `spec/services/tutor/process_message_spec.rb`. Append a new `context "spotting phase integration"` block:
  ```ruby
  context "spotting phase integration" do
    let(:data_hints_answer) do
      create(:answer, question: question,
        correction_text: "Car = 56,73 l",
        data_hints: [
          { "source" => "DT1", "location" => "tableau Consommation moyenne" }
        ])
    end

    before { data_hints_answer }

    let(:spotting_conversation) do
      state = TutorState.new(
        current_phase:        "spotting",
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
      create(:conversation, student: student, subject: exam_subject,
             lifecycle_state: "active", tutor_state: state)
    end

    context "when LLM output contains a forbidden DT reference" do
      before do
        FakeRubyLlm.setup_stub(
          content: "Les données se trouvent dans DT1.",
          tool_calls: []
        )
      end

      it "replaces content with neutral relaunch" do
        result = described_class.call(
          conversation: spotting_conversation,
          question:     question,
          student_input: "Je ne sais pas."
        )
        expect(result.ok?).to be true
        assistant_msg = spotting_conversation.messages.reload.find { |m| m.role == "assistant" }
        expect(assistant_msg.content).to include("Reformule ta réponse")
        expect(assistant_msg.content).not_to include("DT1")
      end
    end

    context "when LLM calls evaluate_spotting with outcome success" do
      let(:spotting_tool_call) do
        double("RubyLLM::ToolCall",
          name: "evaluate_spotting",
          arguments: {
            "task_type_identified" => "calcul",
            "sources_identified"   => ["DT1"],
            "missing_sources"      => [],
            "extra_sources"        => [],
            "feedback_message"     => "Bien repéré !",
            "relaunch_prompt"      => "",
            "outcome"              => "success"
          }
        )
      end

      before do
        FakeRubyLlm.setup_stub(
          content: "Bien repéré !",
          tool_calls: [spotting_tool_call]
        )
      end

      it "broadcasts a data_hints message" do
        expect(ActionCable.server).to receive(:broadcast).with(
          "conversation_#{spotting_conversation.id}",
          hash_including(type: "data_hints")
        ).at_least(:once)

        described_class.call(
          conversation: spotting_conversation,
          question:     question,
          student_input: "Les données sont dans un document technique."
        )
      end

      it "transitions the conversation to guiding phase" do
        described_class.call(
          conversation: spotting_conversation,
          question:     question,
          student_input: "Les données sont dans un document technique."
        )
        expect(spotting_conversation.reload.tutor_state.current_phase).to eq("guiding")
      end

      it "creates a system message with data_hints content" do
        described_class.call(
          conversation: spotting_conversation,
          question:     question,
          student_input: "Les données sont dans un document technique."
        )
        sys_msg = spotting_conversation.messages.reload.find { |m| m.role == "system" }
        expect(sys_msg).to be_present
        expect(sys_msg.content).to include("DT1")
      end
    end

    context "when LLM calls evaluate_spotting with outcome forced_reveal" do
      let(:forced_tool_call) do
        double("RubyLLM::ToolCall",
          name: "evaluate_spotting",
          arguments: {
            "task_type_identified" => "",
            "sources_identified"   => [],
            "missing_sources"      => ["DT1"],
            "extra_sources"        => [],
            "feedback_message"     => "Voici où se trouvent les données.",
            "relaunch_prompt"      => "",
            "outcome"              => "forced_reveal"
          }
        )
      end

      before do
        FakeRubyLlm.setup_stub(
          content: "Voici où se trouvent les données.",
          tool_calls: [forced_tool_call]
        )
      end

      it "also injects data_hints on forced_reveal" do
        described_class.call(
          conversation: spotting_conversation,
          question:     question,
          student_input: "Je ne sais vraiment pas."
        )
        sys_msg = spotting_conversation.messages.reload.find { |m| m.role == "system" }
        expect(sys_msg).to be_present
        expect(sys_msg.content).to include("DT1")
      end
    end
  end
  ```

- [ ] Run only the new examples and confirm they fail:
  ```bash
  bundle exec rspec spec/services/tutor/process_message_spec.rb -e "spotting phase integration" --format documentation 2>&1 | tail -20
  ```
  Expected: failures because `FilterSpottingOutput` and `InjectDataHints` are not yet called.

- [ ] Modify `app/services/tutor/process_message.rb` to wire the two new steps. The existing pipeline sequence is:
  1. `ValidateInput`
  2. `BuildContext`
  3. `CallLlm` → produces `llm_result` with `{ full_content:, tool_calls: }`
  4. `ParseToolCalls`
  5. `ApplyToolCalls`
  6. `UpdateTutorState`
  7. `BroadcastMessage`

  **Step A — Insert `FilterSpottingOutput` between `CallLlm` (step 3) and `ParseToolCalls` (step 4).** Locate the code that calls `CallLlm` and the call to `ParseToolCalls`. Add between them:
  ```ruby
  # Filter forbidden content in spotting phase
  if @conversation.tutor_state.current_phase == "spotting"
    filter_result = FilterSpottingOutput.call(
      message:    assistant_msg,
      llm_output: llm_result.value[:full_content]
    )
    return filter_result if filter_result.err?
  end
  ```

  **Step B — Insert `InjectDataHints` after `ApplyToolCalls` (step 5), before `UpdateTutorState` (step 6).** Locate the result of `ApplyToolCalls` and add after the success check:
  ```ruby
  # Inject data_hints if evaluate_spotting returned a terminal outcome
  spotting_tool = parse_result.value[:parsed].find { |t| t[:name] == "evaluate_spotting" }
  if spotting_tool
    InjectDataHints.call(
      conversation: @conversation,
      question:     @question,
      outcome:      spotting_tool[:args]["outcome"].to_s
    )
  end
  ```

  Note: `parse_result` must be the variable holding the `ParseToolCalls` result. Adjust variable name to match the actual implementation in `process_message.rb`.

- [ ] Run the spotting integration examples:
  ```bash
  bundle exec rspec spec/services/tutor/process_message_spec.rb -e "spotting phase integration" --format documentation 2>&1 | tail -20
  ```
  Expected: `7 examples, 0 failures`.

- [ ] Run the full `process_message_spec.rb` to verify no regressions:
  ```bash
  bundle exec rspec spec/services/tutor/process_message_spec.rb --format documentation 2>&1 | tail -20
  ```
  Expected: 0 failures.

- [ ] Commit:
  ```bash
  git add app/services/tutor/process_message.rb spec/services/tutor/process_message_spec.rb
  git commit -m "feat(tutor): wire FilterSpottingOutput and InjectDataHints into ProcessMessage"
  ```

---

## Task 6 — Run all Tutor unit specs (green gate)

**Files:**
- No file changes
- Commit: none — this is a verification gate before the E2E spec

### Steps

- [ ] Run all tutor-related unit specs:
  ```bash
  bundle exec rspec spec/services/tutor/ spec/models/tutor_state_spec.rb spec/components/data_hints_component_spec.rb --format documentation 2>&1 | tail -30
  ```
  Expected: 0 failures across all files.

- [ ] If any failure is found, fix it before proceeding to Task 7. Do not write the E2E spec until unit specs are fully green.

---

## Task 7 — Spec E2E Capybara `student_tutor_spotting_spec.rb` (remplacement)

**Files:**
- Modify: `spec/features/student_tutor_spotting_spec.rb`
- Commit: `test(feature): replace student_tutor_spotting_spec with new LLM-driven E2E scenarios`

### Context

The current `spec/features/student_tutor_spotting_spec.rb` tests the old QCM-based spotting UI (checkboxes for task_type and sources). This spec must be replaced with scenarios that exercise the new free-text conversational spotting via the `ProcessMessage` pipeline. The old spec is kept as reference for what was removed; the new spec stubs `FakeRubyLlm` to return controlled `evaluate_spotting` tool calls.

The E2E spec tests from the browser layer: it visits the question page, opens the tutor drawer, sends a message, and asserts on what appears in the DOM. It does **not** test `BuildContext` internals — those are covered by unit specs in Task 1.

### Steps

- [ ] Read the current file to understand what is being replaced:
  ```bash
  bundle exec rspec spec/features/student_tutor_spotting_spec.rb --format documentation --dry-run 2>&1 | tail -20
  ```

- [ ] Write the new spec (overwrite the file completely):
  ```ruby
  # spec/features/student_tutor_spotting_spec.rb
  require "rails_helper"

  RSpec.describe "Tuteur guidé : phase de repérage conversationnelle", type: :feature do
    let(:teacher)   { create(:user) }
    let(:classroom) { create(:classroom, name: "Terminale SIN 2026", owner: teacher) }
    let(:student)   { create(:student, classroom: classroom, api_key: "sk-test", api_provider: :anthropic) }
    let(:subject_record) do
      create(:subject, status: :published, owner: teacher,
             specific_presentation: "La société CIME fabrique des véhicules électriques.")
    end
    let(:part) do
      create(:part, :specific, subject: subject_record,
             number: 1, title: "Transport et DD", objective_text: "Comparer les modes.", position: 1)
    end
    let!(:question) do
      create(:question, part: part, number: "1.1",
             label: "Calculer la consommation en litres pour 186 km.",
             answer_type: :calculation, points: 2, position: 1)
    end
    let!(:answer) do
      create(:answer, question: question,
             correction_text: "Car = 56,73 l",
             explanation_text: "Formule Consommation x Distance / 100",
             data_hints: [
               { "source" => "DT1", "location" => "tableau Consommation moyenne" },
               { "source" => "mise_en_situation", "location" => "distance 186 km" }
             ])
    end
    let!(:classroom_subject) { create(:classroom_subject, classroom: classroom, subject: subject_record) }

    let!(:tutored_session) do
      spotting_state = TutorState.new(
        current_phase:        "spotting",
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
      create(:student_session,
             student: student, subject: subject_record,
             mode: :tutored, progression: {},
             tutor_state: spotting_state)
    end

    def visit_question_page
      visit student_question_path(
        access_code: classroom.access_code,
        subject_id:  subject_record.id,
        id:          question.id
      )
      expect(page).to have_css("[data-chat-connected='true']", wait: 10)
    end

    def open_tutor_drawer
      click_button "Tutorat"
      expect(page).to have_css("[data-chat-target='drawer'].translate-x-0", visible: :all, wait: 5)
    end

    before { login_as_student(student, classroom) }

    # Scenario 1: tuteur asks where to find data on entering spotting phase
    scenario "le tuteur demande où trouver les données à l'entrée en phase spotting", js: true do
      FakeRubyLlm.setup_stub(
        content: "Où penses-tu trouver les informations pour cette question ?",
        tool_calls: []
      )

      visit_question_page
      open_tutor_drawer

      # Send a first message to trigger the pipeline
      input = find("[data-chat-target='input']", visible: :all)
      input.fill_in(with: "Bonjour")
      find("[data-chat-target='sendButton']", visible: :all).click

      drawer = find("[data-chat-target='drawer']", visible: :all)
      expect(drawer).to have_text("Où penses-tu trouver les informations", wait: 10)
    end

    # Scenario 2: student answers correctly → data_hints card appears
    scenario "une réponse correcte déclenche l'affichage du DataHintsComponent", js: true do
      success_tool_call = double("RubyLLM::ToolCall",
        name: "evaluate_spotting",
        arguments: {
          "task_type_identified" => "calcul",
          "sources_identified"   => ["DT1", "mise_en_situation"],
          "missing_sources"      => [],
          "extra_sources"        => [],
          "feedback_message"     => "Bien repéré ! Les données sont effectivement dans DT1 et la mise en situation.",
          "relaunch_prompt"      => "",
          "outcome"              => "success"
        }
      )
      FakeRubyLlm.setup_stub(
        content: "Bien repéré ! Les données sont effectivement dans la documentation.",
        tool_calls: [success_tool_call]
      )

      visit_question_page
      open_tutor_drawer

      input = find("[data-chat-target='input']", visible: :all)
      input.fill_in(with: "Je pense que les données sont dans les documents techniques et la mise en situation.")
      find("[data-chat-target='sendButton']", visible: :all).click

      expect(page).to have_css(".data-hints-card", wait: 10)
      expect(page).to have_text("DT1", wait: 5)
      expect(page).to have_text("tableau Consommation moyenne")
      expect(page).to have_text("mise_en_situation")
      expect(page).to have_text("distance 186 km")
    end

    # Scenario 3: 3 wrong answers → forced_reveal → data_hints card appears
    scenario "3 relances échouées → forced_reveal → DataHintsComponent affiché", js: true do
      forced_tool_call = double("RubyLLM::ToolCall",
        name: "evaluate_spotting",
        arguments: {
          "task_type_identified" => "",
          "sources_identified"   => [],
          "missing_sources"      => ["DT1", "mise_en_situation"],
          "extra_sources"        => [],
          "feedback_message"     => "Je vais t'indiquer où se trouvaient les données.",
          "relaunch_prompt"      => "",
          "outcome"              => "forced_reveal"
        }
      )
      FakeRubyLlm.setup_stub(
        content: "Je vais t'indiquer où se trouvaient les données.",
        tool_calls: [forced_tool_call]
      )

      visit_question_page
      open_tutor_drawer

      input = find("[data-chat-target='input']", visible: :all)
      input.fill_in(with: "Je ne sais vraiment pas.")
      find("[data-chat-target='sendButton']", visible: :all).click

      expect(page).to have_css(".data-hints-card", wait: 10)
      expect(page).to have_text("DT1")
      expect(page).to have_text("tableau Consommation moyenne")
    end

    # Scenario 4: LLM output with DT reference → regex filter fires → neutral relaunch shown
    scenario "le filtre regex remplace un output LLM contenant 'DT1' par un relance neutre", js: true do
      FakeRubyLlm.setup_stub(
        content: "Les données se trouvent dans DT1, tableau page 3.",
        tool_calls: []
      )

      visit_question_page
      open_tutor_drawer

      input = find("[data-chat-target='input']", visible: :all)
      input.fill_in(with: "Je pense que c'est dans l'énoncé.")
      find("[data-chat-target='sendButton']", visible: :all).click

      drawer = find("[data-chat-target='drawer']", visible: :all)
      expect(drawer).to have_text("Reformule ta réponse", wait: 10)
      expect(drawer).not_to have_text("DT1")
    end
  end
  ```

- [ ] Run the new E2E spec in dry-run first to confirm it parses correctly:
  ```bash
  bundle exec rspec spec/features/student_tutor_spotting_spec.rb --dry-run --format documentation 2>&1 | tail -20
  ```
  Expected: 4 scenarios listed, 0 errors.

- [ ] Run the spec for real (this will be slow due to JS driver):
  ```bash
  bundle exec rspec spec/features/student_tutor_spotting_spec.rb --format documentation 2>&1 | tail -30
  ```
  Expected: `4 examples, 0 failures`.

  If failures occur, check:
  - `FakeRubyLlm.setup_stub` is being picked up (the support file is auto-required via `spec/support/**/*.rb` glob in `rails_helper.rb`)
  - The tutor drawer renders correctly (check `student_ai_tutoring_spec.rb` for the correct CSS selectors)
  - The `ProcessTutorMessageJob` (Sidekiq) is configured in test mode with `perform_inline` — if not, `FakeRubyLlm` stubs run synchronously through `perform_now` in tests

- [ ] Run the full feature suite to verify no regressions:
  ```bash
  bundle exec rspec spec/features/ --format progress 2>&1 | tail -20
  ```
  Expected: 0 failures (or only pre-existing xfeature-tagged failures).

- [ ] Commit:
  ```bash
  git add spec/features/student_tutor_spotting_spec.rb
  git commit -m "test(feature): replace student_tutor_spotting_spec with new LLM-driven E2E scenarios"
  ```

---

## Task 8 — Run complet de la suite Vague 3

**Files:**
- No file changes
- Commit: none — verification gate

### Steps

- [ ] Run all specs added or modified in this vague:
  ```bash
  bundle exec rspec \
    spec/services/tutor/build_context_spec.rb \
    spec/services/tutor/filter_spotting_output_spec.rb \
    spec/services/tutor/inject_data_hints_spec.rb \
    spec/services/tutor/process_message_spec.rb \
    spec/components/data_hints_component_spec.rb \
    spec/features/student_tutor_spotting_spec.rb \
    --format documentation 2>&1 | tail -40
  ```
  Expected: 0 failures.

- [ ] Run the full RSpec suite to verify no global regressions:
  ```bash
  bundle exec rspec --format progress 2>&1 | tail -10
  ```
  Expected: 0 new failures (any pre-existing xfeature failures are acceptable if they were already tagged before Vague 3).

---

## Récapitulatif des fichiers créés / modifiés

| Fichier | Action |
|---|---|
| `app/services/tutor/build_context.rb` | Modifié — constante `SPOTTING_SECTION` + injection conditionnelle |
| `app/services/tutor/filter_spotting_output.rb` | Créé |
| `app/services/tutor/inject_data_hints.rb` | Créé |
| `app/services/tutor/process_message.rb` | Modifié — 2 nouvelles étapes dans le pipeline |
| `app/components/data_hints_component.rb` | Créé |
| `app/components/data_hints_component.html.erb` | Créé |
| `spec/services/tutor/build_context_spec.rb` | Modifié — 5 nouveaux exemples spotting |
| `spec/services/tutor/filter_spotting_output_spec.rb` | Créé |
| `spec/services/tutor/inject_data_hints_spec.rb` | Créé |
| `spec/services/tutor/process_message_spec.rb` | Modifié — 7 nouveaux exemples |
| `spec/components/data_hints_component_spec.rb` | Créé |
| `spec/features/student_tutor_spotting_spec.rb` | Remplacé |

## Ordre des commits attendus

1. `feat(tutor): inject spotting phase rules into BuildContext system prompt`
2. `feat(tutor): add Tutor::FilterSpottingOutput post-LLM regex filter`
3. `feat(tutor): add DataHintsComponent ViewComponent`
4. `feat(tutor): add Tutor::InjectDataHints service`
5. `feat(tutor): wire FilterSpottingOutput and InjectDataHints into ProcessMessage`
6. `test(feature): replace student_tutor_spotting_spec with new LLM-driven E2E scenarios`
