# Tuteur — redesign from scratch (062) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remplacer la mécanique tuteur 049 (machine d'état 9 phases pilotée par le LLM via 4 tools) par une architecture où le code Ruby pilote la trace, les chips et la phase dérivée — le LLM ne fait que parler en respectant un budget d'aide affiché.

**Architecture:** Approche F — un seul appel LLM par tour (chemin critique), suivi inline d'un classifier asynchrone (haiku 4.5) qui annote ce que le tuteur a fait. La phase est dérivée d'une `QuestionTrace` d'events bruts ; les chips sont calculés depuis un mapping calibré `(answer_type, phase) → chips`. Cap déterministe sur le résultat final via compteurs visibles dans le prompt.

**Tech Stack:** Ruby 3.3+, Rails 8.1.3, RubyLLM (gem existante), Hotwire (Turbo Streams + Stimulus), ActionCable, RSpec + FactoryBot + Capybara/Cuprite, Anthropic SDK pour le classifier (clé serveur).

**Reference docs:**
- Spec: `docs/superpowers/specs/2026-05-06-tutor-redesign-from-scratch-design.md`
- Chips mapping: `docs/superpowers/specs/2026-05-06-tutor-redesign-chips-mapping.md`

**Working directory:** `.worktrees/062-tutor-redesign-from-scratch/` on branch `062-tutor-redesign-from-scratch`. All Bash commands assume this is the cwd.

**Conventional Commits:** every commit must follow `<type>(<scope>): <description>`. One concern per commit. Push and check CI green after each step group when feasible.

**Test command shortcut:**
- Unit specs: `bundle exec rspec spec/services/tutor/<file>_spec.rb`
- Feature specs: `bundle exec rspec spec/features/<file>_spec.rb`
- Full suite: `bundle exec rspec`

---

## File Structure Overview

### Files created

```
app/models/question_trace.rb                                    # Data class
app/services/tutor/derive_phase.rb                              # Pure function
app/services/tutor/record_event.rb                              # Append-only writer
app/services/tutor/classify.rb                                  # Background classifier
app/services/tutor/behavior_hints.rb                            # Static mapping
app/services/tutor/broadcast_done.rb                            # Final payload broadcaster

app/controllers/student/events_controller.rb                    # POST events page

config/initializers/anthropic_classifier.rb                     # Server key wiring (or use existing creds)

db/migrate/<timestamp>_reboot_tutor_state_for_062.rb            # Migration

docs/superpowers/specs/2026-05-06-tutor-redesign-chips-mapping.md  # already added in spec commit

spec/models/question_trace_spec.rb
spec/services/tutor/derive_phase_spec.rb
spec/services/tutor/record_event_spec.rb
spec/services/tutor/classify_spec.rb
spec/services/tutor/behavior_hints_spec.rb
spec/services/tutor/broadcast_done_spec.rb
spec/services/tutor/cross_provider_spec.rb                      # 4 providers
spec/requests/student/events_spec.rb
spec/features/student_tutor_events_page_spec.rb
spec/features/student_tutor_navigation_spec.rb                  # Option A + sans-doublons
spec/features/student_tutor_cap_results_spec.rb                 # cap behavior
```

### Files heavily refactored

```
app/models/tutor_state.rb                                       # Data class — new format
app/models/types/tutor_state_type.rb                            # serializer for new format
app/models/conversation.rb                                      # AASM 5→3
app/services/tutor/process_message.rb                           # orchestrator rewrite
app/services/tutor/build_context.rb                             # 6-block prompt
app/services/tutor/chips_presenter.rb                           # rewrite: import calibrated map
app/services/tutor/broadcast_message.rb                         # split with broadcast_done
app/controllers/student/conversations_controller.rb             # silent create + drawer behavior
app/views/student/conversations/_drawer.html.erb                # filter messages by question_id
app/views/student/conversations/_chips.html.erb                 # render new chip shape
app/javascript/controllers/tutor_chat_controller.js             # nav follow + chip greyed
config/routes.rb                                                # add /events POST
app/services/tutor_simulation/structural_metrics.rb             # rewrite metrics
lib/tasks/tutor_simulate.rake                                   # expose new metrics
.github/workflows/tutor_simulation.yml                          # SC-A + SC-B thresholds
```

### Files DELETED

```
app/services/tutor/apply_tool_calls.rb
app/services/tutor/parse_tool_calls.rb
app/services/tutor/filter_spotting_output.rb
app/services/tutor/inject_data_hints.rb
app/services/tutor/update_tutor_state.rb
app/services/tutor/build_intro_message.rb
app/services/tutor/build_welcome_message.rb
app/services/tutor/tools/transition_tool.rb
app/services/tutor/tools/request_hint_tool.rb
app/services/tutor/tools/evaluate_spotting_tool.rb
app/services/tutor/tools/update_learner_model_tool.rb
app/services/tutor/tools/                                        # empty dir removed

spec/services/tutor/apply_tool_calls_spec.rb
spec/services/tutor/parse_tool_calls_spec.rb
spec/services/tutor/filter_spotting_output_spec.rb
spec/services/tutor/inject_data_hints_spec.rb
spec/services/tutor/update_tutor_state_spec.rb
spec/services/tutor/build_intro_message_spec.rb
spec/services/tutor/build_welcome_message_spec.rb
spec/services/tutor/tools/                                       # all 4 tool specs

spec/features/student_tutor_spotting_spec.rb                     # phase disparue
```

### Files unchanged (kept as-is)

```
app/services/tutor/result.rb
app/services/tutor/no_api_key_error.rb
app/services/tutor/validate_input.rb
app/services/tutor/call_llm.rb                                   # only remove with_tools(...)
app/services/resolve_tutor_api_key.rb
app/jobs/process_tutor_message_job.rb
app/channels/conversation_channel.rb
app/javascript/controllers/tutor_activator_controller.js         # activation flow unchanged
spec/services/tutor/result_spec.rb
spec/services/tutor/validate_input_spec.rb
spec/services/tutor/call_llm_spec.rb                             # update tests for no tools
spec/services/resolve_tutor_api_key_spec.rb
spec/channels/conversation_channel_spec.rb
spec/jobs/process_tutor_message_job_spec.rb                      # update for new flow
```

---

## Phase 1 — Data foundation (migration + types)

### Task 1: Generate the reboot migration

**Files:**
- Create: `db/migrate/<timestamp>_reboot_tutor_state_for_062.rb`

- [ ] **Step 1: Generate the migration skeleton**

Run: `bundle exec rails generate migration RebootTutorStateFor062`

This creates `db/migrate/<timestamp>_reboot_tutor_state_for_062.rb` with empty `change` method.

- [ ] **Step 2: Replace skeleton with reset logic**

Replace the entire file content with:

```ruby
class RebootTutorStateFor062 < ActiveRecord::Migration[8.1]
  def up
    # 062: complete reset of tutor_state JSONB.
    # Conversations and Messages are kept; only the JSONB blob is wiped so that
    # the new TutorStateType can hydrate fresh state on first read.
    Conversation.in_batches(of: 500) do |batch|
      batch.update_all(tutor_state: {})
    end

    # AASM trims: validating/feedback removed in 062. Map them to active so
    # existing rows match the new state machine.
    Conversation.where(lifecycle_state: %w[validating feedback])
                .update_all(lifecycle_state: "active")
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
```

- [ ] **Step 3: Run the migration on local dev db**

Run: `bundle exec rails db:migrate`
Expected: `== <timestamp> RebootTutorStateFor062: migrating ===` and `migrated` lines, no errors.

- [ ] **Step 4: Run the migration on test db**

Run: `bundle exec rails db:migrate RAILS_ENV=test`
Expected: same behavior, no errors.

- [ ] **Step 5: Commit**

```bash
git add db/migrate/*reboot_tutor_state_for_062.rb db/schema.rb
git commit -m "feat(tutor): reboot tutor_state for 062 redesign

Wipe conversations.tutor_state JSONB; remap lifecycle_state
validating/feedback rows to active to match the upcoming
3-state AASM (disabled/active/done)."
```

---

### Task 2: Rewrite `TutorState` Data class with new shape

**Files:**
- Modify: `app/models/tutor_state.rb` (full rewrite)
- Modify: `spec/models/types/tutor_state_type_spec.rb` (will be updated in Task 3 — this task only touches the Data class)

- [ ] **Step 1: Write a failing spec for the new shape**

Create `spec/models/tutor_state_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe TutorState do
  describe ".default" do
    subject(:state) { described_class.default }

    it "exposes the new 062 fields" do
      expect(state.current_question_id).to be_nil
      expect(state.greeted).to be(false)
      expect(state.question_traces).to eq({})
      expect(state.concepts_seen).to eq([])
    end

    it "is frozen-friendly (members are final)" do
      expect { state.current_question_id = 1 }.to raise_error(NoMethodError)
    end
  end

  describe "invariant: phase is never persisted in TutorState" do
    it "TutorState members do not include :phase or :current_phase" do
      forbidden = %i[phase current_phase]
      expect(described_class.members & forbidden).to be_empty
    end
  end

  describe "QuestionTrace#budget" do
    it "computes formule_given from a tutor_gave event with what=formule" do
      trace = QuestionTrace.new(
        question_id: 42,
        events: [
          { "type" => "tutor_gave", "what" => "formule", "at" => Time.current.iso8601, "source" => "classifier" }
        ]
      )
      expect(trace.budget[:formule_given]).to be(true)
      expect(trace.budget[:value_given]).to be(false)
    end
  end
end
```

- [ ] **Step 2: Run the spec to verify it fails**

Run: `bundle exec rspec spec/models/tutor_state_spec.rb`
Expected: FAIL — `TutorState` still has the old members; `QuestionTrace` does not exist yet.

- [ ] **Step 3: Replace `app/models/tutor_state.rb` with the new shape**

Full replacement:

```ruby
# 062: TutorState root and QuestionTrace per-question.
# - Pas de champ phase persisté (la phase est dérivée par Tutor::DerivePhase).
# - QuestionTrace.events est append-only; budget est calculé à la volée.

QuestionTrace = Data.define(:question_id, :events) do
  def self.empty(question_id:)
    new(question_id: question_id, events: [].freeze)
  end

  def append(event)
    new(question_id: question_id, events: events + [event].freeze)
  end

  def budget
    {
      formule_given:     event_present?("tutor_gave", "what" => "formule"),
      value_given:       event_present?("tutor_gave", "what" => "valeur"),
      calc_given:        event_present?("tutor_gave", "what" => "calcul"),
      result_given:      event_present?("tutor_gave", "what" => "résultat"),
      attempts_count:    events.count { |e| e["type"] == "student_attempt" },
      viewed_correction: event_present?("viewed_correction")
    }
  end

  def cap_active?
    !budget[:viewed_correction] && budget[:attempts_count] < 2
  end

  def last_signal
    events.last
  end

  private

  def event_present?(type, match = {})
    events.any? do |e|
      e["type"] == type && match.all? { |k, v| e[k.to_s] == v }
    end
  end
end

TutorState = Data.define(
  :current_question_id,
  :greeted,
  :question_traces,
  :concepts_seen
) do
  def self.default
    new(
      current_question_id: nil,
      greeted:             false,
      question_traces:     {}.freeze,
      concepts_seen:       [].freeze
    )
  end

  def trace_for(question_id)
    question_traces[question_id.to_s] || QuestionTrace.empty(question_id: question_id)
  end

  def with_trace(trace)
    new_traces = question_traces.merge(trace.question_id.to_s => trace).freeze
    with(question_traces: new_traces)
  end

  def with_concept(concept)
    return self if concept.blank? || concepts_seen.include?(concept)
    with(concepts_seen: (concepts_seen + [concept]).freeze)
  end
end
```

- [ ] **Step 4: Run the spec to verify it passes**

Run: `bundle exec rspec spec/models/tutor_state_spec.rb`
Expected: 3 examples, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add app/models/tutor_state.rb spec/models/tutor_state_spec.rb
git commit -m "feat(tutor): introduce 062 TutorState + QuestionTrace shape

QuestionTrace stores append-only events and computes budget on the fly.
TutorState exposes greeted/current_question_id/question_traces/concepts_seen.
Phase is never persisted — invariant enforced by spec."
```

---

### Task 3: Rewrite `TutorStateType` to serialize the new shape

**Files:**
- Modify: `app/models/types/tutor_state_type.rb`
- Modify: `spec/models/types/tutor_state_type_spec.rb`

- [ ] **Step 1: Write a failing spec for serialize/deserialize roundtrip**

Replace `spec/models/types/tutor_state_type_spec.rb` with:

```ruby
require "rails_helper"

RSpec.describe TutorStateType do
  let(:type) { described_class.new }

  describe "#deserialize" do
    it "returns TutorState.default for nil/empty" do
      expect(type.deserialize(nil)).to eq(TutorState.default)
      expect(type.deserialize("{}")).to eq(TutorState.default)
    end

    it "rebuilds TutorState from serialized hash" do
      raw = {
        "current_question_id" => 42,
        "greeted"             => true,
        "question_traces"     => {
          "42" => {
            "question_id" => 42,
            "events"      => [
              { "type" => "viewed_data_hints", "at" => "2026-05-06T10:00:00Z", "source" => "page_click" }
            ]
          }
        },
        "concepts_seen"       => ["loi d'Ohm"]
      }
      state = type.deserialize(raw.to_json)

      expect(state.current_question_id).to eq(42)
      expect(state.greeted).to be(true)
      expect(state.concepts_seen).to eq(["loi d'Ohm"])
      trace = state.trace_for(42)
      expect(trace.events.length).to eq(1)
      expect(trace.events.first["type"]).to eq("viewed_data_hints")
    end

    it "tolerates missing fields with defaults" do
      state = type.deserialize({}.to_json)
      expect(state).to eq(TutorState.default)
    end
  end

  describe "#serialize" do
    it "produces a JSON-safe hash that roundtrips through deserialize" do
      original = TutorState.default
        .with(current_question_id: 7, greeted: true)
        .with_trace(QuestionTrace.empty(question_id: 7).append({
          "type" => "student_attempt", "at" => "2026-05-06T10:00:00Z",
          "source" => "llm_message", "content" => "5673", "verdict" => "incorrect"
        }))

      blob = type.serialize(original)
      restored = type.deserialize(blob)

      expect(restored).to eq(original)
    end
  end
end
```

- [ ] **Step 2: Run the spec to verify it fails**

Run: `bundle exec rspec spec/models/types/tutor_state_type_spec.rb`
Expected: FAIL — old type returns the 049 shape.

- [ ] **Step 3: Replace `app/models/types/tutor_state_type.rb`**

```ruby
class TutorStateType < ActiveRecord::Type::Json
  def deserialize(value)
    raw = value.is_a?(String) ? super(value) : value
    raw = {} if raw.blank?
    raw = {} unless raw.is_a?(Hash)

    TutorState.new(
      current_question_id: raw["current_question_id"],
      greeted:             raw["greeted"] == true,
      question_traces:     deserialize_traces(raw["question_traces"]),
      concepts_seen:       Array(raw["concepts_seen"]).map(&:to_s).freeze
    )
  end

  def serialize(value)
    return super({}) if value.nil?
    raise ArgumentError, "expected TutorState, got #{value.class}" unless value.is_a?(TutorState)

    super(
      "current_question_id" => value.current_question_id,
      "greeted"             => value.greeted,
      "question_traces"     => value.question_traces.transform_values { |t| serialize_trace(t) },
      "concepts_seen"       => value.concepts_seen
    )
  end

  private

  def deserialize_traces(raw)
    return {}.freeze unless raw.is_a?(Hash)

    raw.each_with_object({}) do |(qid, payload), acc|
      events = Array(payload["events"]).map(&:dup)
      acc[qid.to_s] = QuestionTrace.new(
        question_id: payload["question_id"]&.to_i || qid.to_i,
        events:      events.freeze
      )
    end.freeze
  end

  def serialize_trace(trace)
    {
      "question_id" => trace.question_id,
      "events"      => trace.events
    }
  end
end
```

- [ ] **Step 4: Run the spec to verify it passes**

Run: `bundle exec rspec spec/models/types/tutor_state_type_spec.rb`
Expected: 4 examples, 0 failures.

- [ ] **Step 5: Run the full model specs to catch regressions**

Run: `bundle exec rspec spec/models/`
Expected: existing specs still passing OR documented failures only on conversation_aasm_spec (handled later).

If `conversation_aasm_spec.rb` fails on validating/feedback states, leave it for now — Task 12 rewrites it.

- [ ] **Step 6: Commit**

```bash
git add app/models/types/tutor_state_type.rb spec/models/types/tutor_state_type_spec.rb
git commit -m "feat(tutor): rewrite TutorStateType serializer for 062 shape

JSONB serialize/deserialize for the new TutorState/QuestionTrace.
Tolerates legacy {} blobs (post-RebootTutorStateFor062 migration)."
```

---

## Phase 2 — Pure services (no LLM dependency)

### Task 4: `Tutor::DerivePhase` (pure function)

**Files:**
- Create: `app/services/tutor/derive_phase.rb`
- Create: `spec/services/tutor/derive_phase_spec.rb`

- [ ] **Step 1: Write the failing spec**

```ruby
require "rails_helper"

RSpec.describe Tutor::DerivePhase do
  let(:answer_type) { "calcul" }

  def trace_with(events)
    QuestionTrace.new(question_id: 1, events: events.freeze)
  end

  it "returns :fresh on empty trace" do
    expect(described_class.call(trace: trace_with([]), answer_type: answer_type)).to eq(:fresh)
  end

  it "returns :armed after viewed_data_hints" do
    events = [{ "type" => "viewed_data_hints", "source" => "page_click", "at" => "2026-05-06T10:00:00Z" }]
    expect(described_class.call(trace: trace_with(events), answer_type: answer_type)).to eq(:armed)
  end

  it "returns :armed after tutor_gave formule" do
    events = [{ "type" => "tutor_gave", "what" => "formule", "source" => "classifier", "at" => "2026-05-06T10:00:00Z" }]
    expect(described_class.call(trace: trace_with(events), answer_type: answer_type)).to eq(:armed)
  end

  it "returns :debug after a single incorrect student_attempt" do
    events = [{
      "type" => "student_attempt", "verdict" => "incorrect", "content" => "5673",
      "source" => "llm_message", "at" => "2026-05-06T10:00:00Z"
    }]
    expect(described_class.call(trace: trace_with(events), answer_type: answer_type)).to eq(:debug)
  end

  it "returns :done after a correct student_attempt" do
    events = [{
      "type" => "student_attempt", "verdict" => "correct", "content" => "56,73",
      "source" => "llm_message", "at" => "2026-05-06T10:00:00Z"
    }]
    expect(described_class.call(trace: trace_with(events), answer_type: answer_type)).to eq(:done)
  end

  it "returns :done after viewed_correction" do
    events = [{ "type" => "viewed_correction", "source" => "page_click", "at" => "2026-05-06T10:00:00Z" }]
    expect(described_class.call(trace: trace_with(events), answer_type: answer_type)).to eq(:done)
  end

  it "returns :close when nearly there (calcul: incorrect within 5% of nothing — fallback :debug)" do
    # close requires last attempt content within 5% of expected; without expected
    # value, we treat as :debug (safe fallback). Actual close detection is
    # opt-in via expected_value parameter (covered in Step 3).
    events = [{
      "type" => "student_attempt", "verdict" => "incorrect", "content" => "57",
      "source" => "llm_message", "at" => "2026-05-06T10:00:00Z"
    }]
    expect(described_class.call(trace: trace_with(events), answer_type: answer_type)).to eq(:debug)
  end

  it "returns :close when last attempt within 5% of expected_value" do
    events = [{
      "type" => "student_attempt", "verdict" => "incorrect", "content" => "57",
      "source" => "llm_message", "at" => "2026-05-06T10:00:00Z"
    }]
    expect(described_class.call(
      trace:          trace_with(events),
      answer_type:    answer_type,
      expected_value: 56.73
    )).to eq(:close)
  end

  describe "answer_type variations" do
    it "for qcm: skips :close (no continuous proximity)" do
      events = [{
        "type" => "student_attempt", "verdict" => "incorrect", "content" => "B",
        "source" => "llm_message", "at" => "2026-05-06T10:00:00Z"
      }]
      expect(described_class.call(
        trace:          trace_with(events),
        answer_type:    "qcm",
        expected_value: "C"
      )).to eq(:debug)
    end
  end
end
```

- [ ] **Step 2: Run to verify failure**

Run: `bundle exec rspec spec/services/tutor/derive_phase_spec.rb`
Expected: FAIL — `Tutor::DerivePhase` does not exist.

- [ ] **Step 3: Implement the service**

Create `app/services/tutor/derive_phase.rb`:

```ruby
module Tutor
  # Pure function: (trace, answer_type, expected_value?) → Symbol
  # Phases possible: :fresh :armed :debug :close :done
  # Never persisted. Read-only signal for ChipsPresenter and sim metrics.
  class DerivePhase
    CLOSE_TOLERANCE = 0.05  # 5% relative tolerance for numeric :close

    def self.call(trace:, answer_type:, expected_value: nil)
      return :done   if done?(trace)
      return :close  if close?(trace, answer_type, expected_value)
      return :debug  if has_incorrect_attempt?(trace)
      return :armed  if armed?(trace)

      :fresh
    end

    def self.done?(trace)
      trace.events.any? do |e|
        e["type"] == "viewed_correction" ||
          (e["type"] == "student_attempt" && e["verdict"] == "correct") ||
          e["type"] == "marked_done"
      end
    end

    def self.armed?(trace)
      trace.events.any? do |e|
        e["type"] == "viewed_data_hints" ||
          (e["type"] == "tutor_gave" && %w[formule structure élimination critère].include?(e["what"]))
      end
    end

    def self.has_incorrect_attempt?(trace)
      trace.events.any? do |e|
        e["type"] == "student_attempt" && e["verdict"] == "incorrect"
      end
    end

    def self.close?(trace, answer_type, expected_value)
      return false unless answer_type == "calcul"
      return false if expected_value.nil?

      last_attempt = trace.events.reverse.find { |e| e["type"] == "student_attempt" }
      return false unless last_attempt && last_attempt["content"]

      attempt_value = numeric_value(last_attempt["content"])
      expected      = numeric_value(expected_value)
      return false if attempt_value.nil? || expected.nil? || expected.zero?

      ((attempt_value - expected).abs / expected.abs) <= CLOSE_TOLERANCE
    end

    def self.numeric_value(raw)
      Float(raw.to_s.tr(",", ".").gsub(/[^\d.\-]/, ""))
    rescue ArgumentError, TypeError
      nil
    end
  end
end
```

- [ ] **Step 4: Run the spec to verify it passes**

Run: `bundle exec rspec spec/services/tutor/derive_phase_spec.rb`
Expected: 9 examples, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add app/services/tutor/derive_phase.rb spec/services/tutor/derive_phase_spec.rb
git commit -m "feat(tutor): add DerivePhase pure function

Computes :fresh|:armed|:debug|:close|:done from QuestionTrace events
and answer_type. Never persisted. Read-only signal for ChipsPresenter
and sim metrics."
```

---

### Task 5: `Tutor::RecordEvent` (append-only writer)

**Files:**
- Create: `app/services/tutor/record_event.rb`
- Create: `spec/services/tutor/record_event_spec.rb`

- [ ] **Step 1: Write the failing spec**

```ruby
require "rails_helper"

RSpec.describe Tutor::RecordEvent do
  let(:student) { create(:student) }
  let(:subject_record) { create(:subject) }
  let!(:question) { create(:question, part: create(:part, subject: subject_record)) }
  let!(:conversation) do
    create(:conversation, student: student, subject: subject_record, tutor_state: TutorState.default)
  end

  describe "appending an event to the current question's trace" do
    it "appends and persists the event" do
      result = described_class.call(
        conversation: conversation,
        question_id:  question.id,
        type:         "viewed_data_hints",
        source:       "page_click"
      )

      expect(result.ok?).to be(true)
      conversation.reload
      trace = conversation.tutor_state.trace_for(question.id)
      expect(trace.events.length).to eq(1)
      expect(trace.events.first["type"]).to eq("viewed_data_hints")
      expect(trace.events.first["source"]).to eq("page_click")
      expect(trace.events.first).to have_key("at")
    end

    it "is append-only (existing events untouched)" do
      described_class.call(conversation: conversation, question_id: question.id,
                           type: "viewed_data_hints", source: "page_click")
      described_class.call(conversation: conversation, question_id: question.id,
                           type: "student_attempt", source: "llm_message",
                           content: "5673", verdict: "incorrect")

      conversation.reload
      trace = conversation.tutor_state.trace_for(question.id)
      expect(trace.events.map { |e| e["type"] }).to eq(%w[viewed_data_hints student_attempt])
    end

    it "updates current_question_id when navigated_here event is recorded" do
      described_class.call(conversation: conversation, question_id: question.id,
                           type: "navigated_here", source: "code")

      conversation.reload
      expect(conversation.tutor_state.current_question_id).to eq(question.id)
    end

    it "does not alter current_question_id for non-navigation events" do
      conversation.update!(tutor_state: TutorState.default.with(current_question_id: 999))
      described_class.call(conversation: conversation, question_id: question.id,
                           type: "viewed_data_hints", source: "page_click")

      conversation.reload
      expect(conversation.tutor_state.current_question_id).to eq(999)
    end
  end

  describe "invariant: append-only" do
    it "preserves all prior events and their order" do
      events = []
      5.times do |i|
        described_class.call(conversation: conversation, question_id: question.id,
                             type: "tutor_gave", source: "classifier", what: "formule")
        events << "tutor_gave"
      end

      conversation.reload
      trace = conversation.tutor_state.trace_for(question.id)
      expect(trace.events.map { |e| e["type"] }).to eq(events)
    end
  end
end
```

- [ ] **Step 2: Run to verify failure**

Run: `bundle exec rspec spec/services/tutor/record_event_spec.rb`
Expected: FAIL.

- [ ] **Step 3: Implement the service**

Create `app/services/tutor/record_event.rb`:

```ruby
module Tutor
  # Append-only writer of events to a Conversation's TutorState.
  # Atomic: re-reads, builds new state, persists in one update!.
  # Updates current_question_id only on navigated_here events.
  class RecordEvent
    ALLOWED_TYPES = %w[
      viewed_data_hints viewed_correction navigated_here
      student_attempt tutor_gave marked_done concept_seen
      cap_violation
    ].freeze

    ALLOWED_SOURCES = %w[page_click chip_click llm_message classifier code].freeze

    def self.call(conversation:, question_id:, type:, source:, **payload)
      new(
        conversation: conversation,
        question_id:  question_id,
        type:         type,
        source:       source,
        payload:      payload
      ).call
    end

    def initialize(conversation:, question_id:, type:, source:, payload:)
      @conversation = conversation
      @question_id  = question_id
      @type         = type.to_s
      @source       = source.to_s
      @payload      = payload
    end

    def call
      return Result.err("type interdit: #{@type}")     unless ALLOWED_TYPES.include?(@type)
      return Result.err("source interdite: #{@source}") unless ALLOWED_SOURCES.include?(@source)

      event = build_event
      Conversation.transaction do
        conv = Conversation.lock.find(@conversation.id)
        new_state = build_new_state(conv.tutor_state, event)
        conv.update!(tutor_state: new_state)
      end

      Result.ok(event: event)
    end

    private

    def build_event
      {
        "type"   => @type,
        "source" => @source,
        "at"     => Time.current.iso8601
      }.merge(@payload.transform_keys(&:to_s).compact)
    end

    def build_new_state(state, event)
      trace      = state.trace_for(@question_id)
      new_trace  = trace.append(event)
      new_state  = state.with_trace(new_trace)
      new_state  = new_state.with(current_question_id: @question_id) if @type == "navigated_here"

      if @type == "concept_seen" && @payload[:concept].present?
        new_state = new_state.with_concept(@payload[:concept])
      end

      new_state
    end
  end
end
```

- [ ] **Step 4: Run to verify pass**

Run: `bundle exec rspec spec/services/tutor/record_event_spec.rb`
Expected: 5 examples, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add app/services/tutor/record_event.rb spec/services/tutor/record_event_spec.rb
git commit -m "feat(tutor): add RecordEvent append-only writer

Atomic append of events to QuestionTrace. Updates current_question_id
only on navigated_here events. Preserves all prior events (invariant 1)."
```

---

### Task 6: `Tutor::ChipsPresenter` rewrite with calibrated mapping

**Files:**
- Modify: `app/services/tutor/chips_presenter.rb` (full rewrite)
- Modify: `spec/services/tutor/chips_presenter_spec.rb` (full rewrite)
- Reference: `docs/superpowers/specs/2026-05-06-tutor-redesign-chips-mapping.md`

- [ ] **Step 1: Write the failing spec**

Replace `spec/services/tutor/chips_presenter_spec.rb` with:

```ruby
require "rails_helper"

RSpec.describe Tutor::ChipsPresenter do
  describe ".call" do
    let(:trace) { QuestionTrace.empty(question_id: 1) }

    it "returns the calcul/fresh chips for a fresh trace on a calcul question" do
      chips = described_class.call(trace: trace, answer_type: "calcul")
      expect(chips).to be_an(Array)
      expect(chips.length).to be_between(3, 4).inclusive
      labels = chips.map { |c| c[:label] }
      expect(labels).to include("C'est quoi la formule ?")
    end

    it "returns the qcm/fresh chips for qcm" do
      chips = described_class.call(trace: trace, answer_type: "qcm")
      expect(chips.map { |c| c[:label] }).to include("Explique les options")
    end

    it "marks 'Donne le résultat' as disabled when cap is active" do
      events = [{ "type" => "student_attempt", "verdict" => "incorrect", "source" => "llm_message",
                  "at" => "2026-05-06T10:00:00Z", "content" => "5673" }]
      trace_one_attempt = QuestionTrace.new(question_id: 1, events: events.freeze)

      chips = described_class.call(trace: trace_one_attempt, answer_type: "calcul")
      result_chip = chips.find { |c| c[:label] == "Donne le résultat" }
      expect(result_chip).not_to be_nil
      expect(result_chip[:disabled]).to be(true)
      expect(result_chip[:tooltip]).to include("Essaie")
    end

    it "marks 'Donne le résultat' as enabled when cap is lifted (2 attempts)" do
      events = 2.times.map do
        { "type" => "student_attempt", "verdict" => "incorrect", "source" => "llm_message",
          "at" => "2026-05-06T10:00:00Z", "content" => "5673" }
      end
      trace_two_attempts = QuestionTrace.new(question_id: 1, events: events.freeze)

      chips = described_class.call(trace: trace_two_attempts, answer_type: "calcul")
      result_chip = chips.find { |c| c[:label] == "Donne le résultat" }
      expect(result_chip[:disabled]).to be(false)
    end

    it "covers all 7 answer_types × 5 phases without raising" do
      answer_types = %w[calcul identification justification representation qcm verification conclusion]
      phases       = %i[fresh armed debug close done]

      answer_types.each do |at|
        phases.each do |ph|
          # Build a trace that yields the desired phase via DerivePhase semantics.
          chips = described_class.for_phase(answer_type: at, phase: ph, cap_active: false)
          expect(chips).to be_an(Array), "missing chips for #{at}/#{ph}"
        end
      end
    end
  end
end
```

- [ ] **Step 2: Run to verify failure**

Run: `bundle exec rspec spec/services/tutor/chips_presenter_spec.rb`
Expected: FAIL — old presenter has different API.

- [ ] **Step 3: Replace `app/services/tutor/chips_presenter.rb` with calibrated mapping**

The full mapping is in `docs/superpowers/specs/2026-05-06-tutor-redesign-chips-mapping.md`. Copy it verbatim into a Ruby `CHIPS_MAPPING` constant. The implementation must:

- Call `DerivePhase.call(...)` to compute the phase from the trace.
- Look up `CHIPS_MAPPING[answer_type.to_sym][phase]`.
- For chips whose payload mentions the final result (`Donne le résultat`, `Donne la réponse`, `Donne la conclusion`, `Donne la justification attendue`, `Donne la bonne option`), set `disabled: true` + `tooltip: "Essaie d'abord ou regarde la correction"` when `trace.cap_active?` is true.

```ruby
module Tutor
  class ChipsPresenter
    # Mapping calibré sur corpus BAC STI2D 2025 (~90 questions).
    # Voir docs/superpowers/specs/2026-05-06-tutor-redesign-chips-mapping.md
    # Importé tel quel — toute modification doit passer par une session
    # sujet-en-main et mettre à jour le doc en parallèle.
    CHIPS_MAPPING = {
      calcul: {
        fresh: [
          { action: "send",       label: "C'est quoi la formule ?",    payload: "Quelle formule je dois utiliser ?" },
          { action: "send",       label: "Quelles données utiliser ?", payload: "Où je trouve les données nécessaires ?" },
          { action: "send",       label: "Je me lance",                payload: "Je commence le calcul, je te montre" },
          { action: "confidence", label: "Je suis perdu",              payload: "low" }
        ],
        armed: [
          { action: "send", label: "Vérifie mes unités",      payload: "Tu peux vérifier mes unités ?" },
          { action: "send", label: "Je bloque sur une étape", payload: "Je bloque sur une étape du calcul" },
          { action: "send", label: "Donne-moi un indice",     payload: "Donne-moi un indice pour avancer" }
        ],
        debug: [
          { action: "send", label: "Où est mon erreur ?",  payload: "Tu peux me dire où est mon erreur ?" },
          { action: "send", label: "Refais avec moi",      payload: "On peut refaire le calcul ensemble étape par étape ?" },
          { action: "send", label: "Vérifie mes unités",   payload: "Je crois que mes unités sont fausses" },
          { action: "send", label: "Donne le résultat",    payload: "Donne-moi le résultat final" }
        ],
        close: [
          { action: "send", label: "Je finalise",        payload: "Je finalise mon calcul, voilà ma réponse" },
          { action: "send", label: "Vérifie ma réponse", payload: "Tu peux vérifier ma réponse finale ?" },
          { action: "send", label: "Donne le résultat",  payload: "Donne-moi le résultat final" }
        ],
        done: [
          { action: "send", label: "Pourquoi ça marche ?", payload: "Pourquoi cette méthode marche ?" },
          { action: "send", label: "Question suivante",    payload: "On passe à la suivante" }
        ]
      },
      identification: {
        fresh: [
          { action: "send",       label: "Où je regarde ?",   payload: "Sur quel document je dois regarder ?" },
          { action: "send",       label: "Explique le terme", payload: "Tu peux m'expliquer le vocabulaire de la question ?" },
          { action: "send",       label: "Je propose",        payload: "Je te propose ma réponse" },
          { action: "confidence", label: "Je suis perdu",     payload: "low" }
        ],
        armed: [
          { action: "send", label: "Donne-moi un indice",  payload: "Donne-moi un indice pour repérer" },
          { action: "send", label: "Quels critères ?",     payload: "Sur quels critères je dois m'appuyer ?" },
          { action: "send", label: "Je propose ça",        payload: "Voilà ce que je propose" }
        ],
        debug: [
          { action: "send", label: "Où j'ai mal lu ?",  payload: "Tu peux me montrer où j'ai mal lu le document ?" },
          { action: "send", label: "Reprends avec moi", payload: "On reprend ensemble la lecture du document" },
          { action: "send", label: "Donne la réponse",  payload: "Donne-moi la bonne réponse" }
        ],
        close: [
          { action: "send", label: "Je confirme",        payload: "Je confirme, c'est bien ça ma réponse" },
          { action: "send", label: "Vérifie ma réponse", payload: "Tu valides ?" },
          { action: "send", label: "Donne la réponse",   payload: "Donne-moi la bonne réponse" }
        ],
        done: [
          { action: "send", label: "Pourquoi ce choix ?", payload: "Pourquoi c'est cette réponse et pas une autre ?" },
          { action: "send", label: "Question suivante",   payload: "On passe à la suivante" }
        ]
      },
      justification: {
        fresh: [
          { action: "send",       label: "Comment structurer ?", payload: "Comment je structure ma justification ?" },
          { action: "send",       label: "Quels arguments ?",    payload: "Sur quels arguments je peux m'appuyer ?" },
          { action: "send",       label: "Je tente",             payload: "Je tente une justification, dis-moi" },
          { action: "confidence", label: "Je suis perdu",        payload: "low" }
        ],
        armed: [
          { action: "send", label: "Donne-moi un indice",  payload: "Donne-moi une piste pour argumenter" },
          { action: "send", label: "Sur quoi m'appuyer ?", payload: "Quels documents ou principes je dois citer ?" },
          { action: "send", label: "Voilà mon idée",       payload: "Voilà mon idée de justification" }
        ],
        debug: [
          { action: "send", label: "Qu'est-ce qui manque ?", payload: "Qu'est-ce qui manque dans mon argumentation ?" },
          { action: "send", label: "Reformule avec moi",    payload: "On reformule ensemble ?" },
          { action: "send", label: "Donne la réponse",      payload: "Donne-moi la justification attendue" }
        ],
        close: [
          { action: "send", label: "Je rédige ma réponse", payload: "Je rédige ma justification finale" },
          { action: "send", label: "Vérifie ma réponse",   payload: "Tu valides ma justification ?" },
          { action: "send", label: "Donne la réponse",     payload: "Donne-moi la justification attendue" }
        ],
        done: [
          { action: "send", label: "Récapitule l'idée clé", payload: "Tu peux récapituler l'idée clé ?" },
          { action: "send", label: "Question suivante",     payload: "On passe à la suivante" }
        ]
      },
      representation: {
        fresh: [
          { action: "navigate",   label: "Ouvrir le DR",     payload: "open_dr" },
          { action: "send",       label: "Où je commence ?", payload: "Par quoi je commence sur le DR ?" },
          { action: "send",       label: "Donne la formule", payload: "Quelle formule pour calculer les valeurs ?" },
          { action: "send",       label: "Je me lance",      payload: "Je commence à compléter, je te dis" },
          { action: "confidence", label: "Je suis perdu",    payload: "low" }
        ],
        armed: [
          { action: "send", label: "Quelle échelle ?",        payload: "Quelle échelle ou convention je dois utiliser ?" },
          { action: "send", label: "Donne la formule",        payload: "Rappelle-moi la formule pour les valeurs" },
          { action: "send", label: "Vérifie mon début",       payload: "Tu peux vérifier ce que j'ai déjà tracé ?" }
        ],
        debug: [
          { action: "send", label: "Où c'est faux ?",   payload: "Quelle partie de mon tracé est fausse ?" },
          { action: "send", label: "Refais avec moi",   payload: "On reprend le tracé étape par étape" },
          { action: "send", label: "Donne la formule",  payload: "Donne-moi la formule pour les valeurs internes" },
          { action: "send", label: "Donne le résultat", payload: "Donne-moi le tracé attendu" }
        ],
        close: [
          { action: "send", label: "Je termine le tracé", payload: "Je finalise mon tracé sur le DR" },
          { action: "send", label: "Vérifie mon tracé",   payload: "Tu peux valider mon tracé final ?" },
          { action: "send", label: "Donne le résultat",   payload: "Donne-moi le tracé attendu" }
        ],
        done: [
          { action: "send", label: "Pourquoi cette forme ?", payload: "Pourquoi le tracé a cette allure ?" },
          { action: "send", label: "Question suivante",      payload: "On passe à la suivante" }
        ]
      },
      qcm: {
        fresh: [
          { action: "send",       label: "Explique les options",  payload: "Tu peux m'expliquer les différentes options ?" },
          { action: "send",       label: "Sur quoi je me base ?", payload: "Sur quel critère je dois choisir ?" },
          { action: "send",       label: "Je choisis",            payload: "Voilà ce que je choisis" },
          { action: "confidence", label: "Je suis perdu",         payload: "low" }
        ],
        armed: [
          { action: "send", label: "Élimine les fausses",  payload: "Aide-moi à éliminer les mauvaises options" },
          { action: "send", label: "Donne-moi un indice",  payload: "Donne-moi un indice pour choisir" },
          { action: "send", label: "Je penche pour…",      payload: "Je penche pour une option, je te dis laquelle" }
        ],
        debug: [
          { action: "send", label: "Pourquoi pas ce choix ?", payload: "Pourquoi mon choix n'est pas le bon ?" },
          { action: "send", label: "Compare les options",     payload: "On compare les options ensemble" },
          { action: "send", label: "Donne la réponse",        payload: "Donne-moi la bonne option" }
        ],
        close: [
          { action: "send", label: "Je confirme mon choix", payload: "Je confirme mon choix final" },
          { action: "send", label: "Vérifie ma réponse",    payload: "Tu valides mon option ?" },
          { action: "send", label: "Donne la réponse",      payload: "Donne-moi la bonne option" }
        ],
        done: [
          { action: "send", label: "Pourquoi cette option ?", payload: "Pourquoi c'est la bonne option ?" },
          { action: "send", label: "Question suivante",       payload: "On passe à la suivante" }
        ]
      },
      verification: {
        fresh: [
          { action: "send",       label: "Quel critère comparer ?", payload: "Quel est le critère de référence à respecter ?" },
          { action: "send",       label: "Quelle valeur seuil ?",   payload: "Quelle est la valeur seuil ou la norme ?" },
          { action: "send",       label: "Je vérifie",              payload: "Je fais la vérification, je te dis" },
          { action: "confidence", label: "Je suis perdu",           payload: "low" }
        ],
        armed: [
          { action: "send", label: "Donne-moi un indice",   payload: "Donne-moi un indice pour comparer" },
          { action: "send", label: "Où trouver le seuil ?", payload: "Sur quel document trouver le critère ?" },
          { action: "send", label: "Voilà ma comparaison",  payload: "Voilà ma comparaison, qu'est-ce que t'en penses ?" }
        ],
        debug: [
          { action: "send", label: "Mauvais critère ?",   payload: "Je me suis trompé de critère ?" },
          { action: "send", label: "Refais avec moi",     payload: "On refait la vérification ensemble" },
          { action: "send", label: "Donne la conclusion", payload: "Donne-moi la conclusion attendue" }
        ],
        close: [
          { action: "send", label: "Je conclus",            payload: "Je rédige ma conclusion : pass ou fail" },
          { action: "send", label: "Vérifie ma conclusion", payload: "Tu valides ma conclusion ?" },
          { action: "send", label: "Donne la conclusion",   payload: "Donne-moi la conclusion attendue" }
        ],
        done: [
          { action: "send", label: "Et si c'était KO ?", payload: "Qu'est-ce qu'on ferait si la vérif était KO ?" },
          { action: "send", label: "Question suivante",   payload: "On passe à la suivante" }
        ]
      },
      conclusion: {
        fresh: [
          { action: "send",       label: "Quoi synthétiser ?",  payload: "Sur quoi je dois m'appuyer pour conclure ?" },
          { action: "send",       label: "Combien de pistes ?", payload: "Combien de pistes ou d'arguments on attend ?" },
          { action: "send",       label: "Je propose",          payload: "Je te propose ma conclusion" },
          { action: "confidence", label: "Je suis perdu",       payload: "low" }
        ],
        armed: [
          { action: "send", label: "Donne-moi un angle",     payload: "Donne-moi un angle pour conclure" },
          { action: "send", label: "Quels résultats clés ?", payload: "Quels résultats clés je dois reprendre ?" },
          { action: "send", label: "Voilà mon idée",         payload: "Voilà mon idée de conclusion" }
        ],
        debug: [
          { action: "send", label: "Qu'est-ce qui manque ?", payload: "Qu'est-ce qui manque dans ma conclusion ?" },
          { action: "send", label: "Reformule avec moi",     payload: "On reformule ensemble la conclusion" },
          { action: "send", label: "Donne la conclusion",    payload: "Donne-moi la conclusion attendue" }
        ],
        close: [
          { action: "send", label: "Je rédige la conclusion", payload: "Je rédige ma conclusion finale" },
          { action: "send", label: "Vérifie ma conclusion",   payload: "Tu valides ma conclusion ?" },
          { action: "send", label: "Donne la conclusion",     payload: "Donne-moi la conclusion attendue" }
        ],
        done: [
          { action: "send", label: "Élargis le sujet",  payload: "Tu peux élargir avec un autre angle DD ?" },
          { action: "send", label: "Question suivante", payload: "On passe à la suivante" }
        ]
      }
    }.freeze

    REVEAL_LABELS = [
      "Donne le résultat", "Donne la réponse", "Donne la conclusion"
    ].freeze

    DISABLED_TOOLTIP = "Essaie d'abord ou regarde la correction".freeze

    def self.call(trace:, answer_type:, expected_value: nil)
      phase = DerivePhase.call(trace: trace, answer_type: answer_type, expected_value: expected_value)
      for_phase(answer_type: answer_type, phase: phase, cap_active: trace.cap_active?)
    end

    def self.for_phase(answer_type:, phase:, cap_active:)
      key = answer_type.to_sym
      raw = CHIPS_MAPPING.dig(key, phase) || []

      raw.map do |chip|
        if cap_active && REVEAL_LABELS.include?(chip[:label])
          chip.merge(disabled: true, tooltip: DISABLED_TOOLTIP)
        else
          chip.merge(disabled: false)
        end
      end
    end
  end
end
```

- [ ] **Step 4: Run to verify pass**

Run: `bundle exec rspec spec/services/tutor/chips_presenter_spec.rb`
Expected: 5 examples, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add app/services/tutor/chips_presenter.rb spec/services/tutor/chips_presenter_spec.rb
git commit -m "feat(tutor): rewrite ChipsPresenter with calibrated mapping

Imports the 7×5 mapping (calcul/identification/justification/representation/
qcm/verification/conclusion × fresh/armed/debug/close/done) calibrated on
BAC STI2D 2025 corpus. Cap-active reveal chips are visually disabled with
tooltip — never hidden, for pedagogical transparency."
```

---

### Task 7: `Tutor::BehaviorHints` static mapping

**Files:**
- Create: `app/services/tutor/behavior_hints.rb`
- Create: `spec/services/tutor/behavior_hints_spec.rb`

- [ ] **Step 1: Write the failing spec**

```ruby
require "rails_helper"

RSpec.describe Tutor::BehaviorHints do
  describe ".for" do
    let(:budget) do
      { formule_given: false, value_given: false, calc_given: false, result_given: false,
        attempts_count: 0, viewed_correction: false }
    end

    it "returns the fresh-open hint when greeted is false" do
      hint = described_class.for(signal: :fresh_open, answer_type: :calcul, budget: budget)
      expect(hint).to include("Salue brièvement")
    end

    it "returns wrong_attempt hint for calcul" do
      hint = described_class.for(
        signal: :wrong_attempt,
        answer_type: :calcul,
        budget: budget.merge(attempts_count: 1)
      )
      expect(hint).to match(/pas ça/i)
      expect(hint).to match(/calcul|détail|unité/i)
    end

    it "differs by answer_type for the same signal" do
      hint_calcul = described_class.for(signal: :wrong_attempt, answer_type: :calcul, budget: budget)
      hint_qcm    = described_class.for(signal: :wrong_attempt, answer_type: :qcm,    budget: budget)
      expect(hint_calcul).not_to eq(hint_qcm)
    end

    it "produces a non-empty hint for any (signal, answer_type) combo (fallback)" do
      signals      = %i[fresh_open opened_after_data_hints opened_after_correction
                        dont_understand wrong_attempt correct_attempt
                        chip_formule chip_valeur chip_calcul chip_resultat
                        navigation_arrival]
      answer_types = %i[calcul identification justification representation qcm verification conclusion]

      signals.each do |s|
        answer_types.each do |at|
          hint = described_class.for(signal: s, answer_type: at, budget: budget)
          expect(hint).to be_a(String).and(satisfy { |x| x.length.positive? })
        end
      end
    end

    it "returns the cap-locked hint for chip_resultat when cap is active" do
      hint = described_class.for(
        signal: :chip_resultat,
        answer_type: :calcul,
        budget: budget.merge(attempts_count: 1, viewed_correction: false)
      )
      expect(hint).to match(/refuse|propose-lui|tentative|correction/i)
    end
  end
end
```

- [ ] **Step 2: Run to verify failure**

Run: `bundle exec rspec spec/services/tutor/behavior_hints_spec.rb`
Expected: FAIL.

- [ ] **Step 3: Implement the service**

Create `app/services/tutor/behavior_hints.rb`:

```ruby
module Tutor
  # Static mapping (signal, answer_type, budget_state) → behavior hint string.
  # Injected in BuildContext as the ACTION ATTENDUE block of the system prompt.
  # Chosen over template-paramétré (option B) for readability and quality of
  # individual phrasings (decision in brainstorm 4.11).
  module BehaviorHints
    DEFAULT_FALLBACK = "Réponds à l'élève en restant prof sympa qui tutoie. " \
                       "Court (1-3 phrases). Permission explicite de donner formule/valeur/calcul si demandé.".freeze

    HINTS = {
      # Signal: fresh_open (1ère ouverture du drawer dans ce sujet)
      fresh_open: lambda do |_at, _budget|
        "Salue brièvement (1 phrase max, ex. \"Salut, je suis là si t'as besoin\"). " \
          "Puis demande où il en est sur la question."
      end,

      # Signal: opened_after_data_hints (élève a vu data_hints, drawer fermé puis ouvert)
      opened_after_data_hints: lambda do |_at, _budget|
        "Il a maintenant les valeurs depuis data_hints. Demande-lui s'il préfère choisir " \
          "la formule ensemble ou tenter le calcul lui-même."
      end,

      # Signal: opened_after_correction (élève a vu correction, drawer fermé puis ouvert)
      # OU réaction live à viewed_correction quand drawer ouvert (Option III)
      opened_after_correction: lambda do |_at, _budget|
        "L'élève a vu la correction officielle. Bascule en mode appropriation : " \
          "demande sur quel passage il veut qu'on revienne (formule, données, calcul, raisonnement)."
      end,

      # Signal: navigation_arrival (élève a navigué vers cette question)
      navigation_arrival: lambda do |_at, budget|
        if budget[:attempts_count].positive?
          "L'élève revient sur cette question (déjà entamée). Rappelle en 1 phrase où vous en étiez, " \
            "puis enchaîne sur le palier courant."
        else
          "L'élève arrive sur cette question pour la première fois. Demande où il bloque ou s'il préfère se lancer."
        end
      end,

      # Signal: dont_understand (élève a écrit "je ne comprends pas" / similar)
      dont_understand: {
        calcul: ->(_b) {
          "Démarre direct : énonce la formule à utiliser, identifie une sous-tâche concrète, " \
            "demande-lui de l'attaquer ou de te dire où il préfère qu'on commence."
        },
        identification: ->(_b) {
          "Démarre direct : pointe le document à consulter et la nature de l'info à repérer. " \
            "Propose-lui de chercher ou demande-lui ce qui le bloque le plus."
        },
        justification: ->(_b) {
          "Démarre direct : propose une structure (argument → preuve → conclusion) et un mot-clé central. " \
            "Demande-lui de tenter une première phrase."
        },
        representation: ->(_b) {
          "Démarre direct : indique par quoi commencer sur le DR (échelle, axes, premier élément). " \
            "Demande-lui s'il veut un guide pas-à-pas ou la formule directement."
        },
        qcm: ->(_b) {
          "Démarre direct : propose un critère de discrimination. Demande-lui d'éliminer 1 option avec ce critère."
        },
        verification: ->(_b) {
          "Démarre direct : nomme le critère à comparer et la valeur de référence. " \
            "Demande-lui de poser le rapport ou la comparaison."
        },
        conclusion: ->(_b) {
          "Démarre direct : propose 1-2 angles à reprendre des questions précédentes. " \
            "Demande-lui de structurer une première phrase de conclusion."
        }
      },

      # Signal: wrong_attempt (élève a fait une tentative incorrecte)
      wrong_attempt: {
        calcul: ->(_b) {
          "Indique que ce n'est pas ça (sans donner la valeur attendue). Demande le détail du calcul. " \
            "Si tu vois une erreur d'unité ou de conversion probable, donne une indication ciblée."
        },
        identification: ->(_b) {
          "Indique que ce n'est pas ça. Demande où il a trouvé sa réponse. " \
            "Oriente vers la bonne source si la sienne est fausse."
        },
        justification: ->(_b) {
          "Indique ce qui manque ou ce qui est inexact. Demande-lui de reformuler en s'appuyant sur un fait précis."
        },
        representation: ->(_b) {
          "Indique quelle partie du tracé est fausse (échelle, position, allure). Refais cette partie ensemble."
        },
        qcm: ->(_b) {
          "Indique que ce n'est pas la bonne option. Demande pourquoi il l'a choisie. " \
            "Oriente vers un critère qui éliminerait son choix."
        },
        verification: ->(_b) {
          "Indique que la conclusion ne tient pas. Vérifie d'abord le critère utilisé puis le calcul du rapport."
        },
        conclusion: ->(_b) {
          "Indique ce qui manque. Pousse-le à enrichir avec un autre angle ou un autre résultat précédent."
        }
      },

      # Signal: correct_attempt
      correct_attempt: lambda do |_at, _budget|
        "Confirme brièvement (sans surenchère). Demande s'il a besoin de précisions ou s'il passe à la suivante."
      end,

      # Signaux de chips
      chip_formule: lambda do |answer_type, _budget|
        case answer_type
        when :representation, :calcul
          "Donne la formule ou la méthode demandée, dans une seule phrase. Demande s'il veut tenter avec, ou continuer ensemble."
        else
          "Donne la structure / méthode demandée, dans une seule phrase. Propose-lui de l'appliquer."
        end
      end,

      chip_valeur: lambda do |_at, _budget|
        "Donne les valeurs identifiées dans le sujet (sans calcul). Demande s'il veut les appliquer lui-même."
      end,

      chip_calcul: lambda do |_at, _budget|
        "Détaille le calcul étape par étape. Ne donne pas le résultat final si le cap est actif. " \
          "Termine par une demande : \"applique-le, dis-moi ce que tu trouves\"."
      end,

      chip_resultat: {
        cap_locked: ->(_at, _b) {
          "Refuse poliment de donner le résultat (cap actif : tentatives < 2 ET correction non vue). " \
            "Propose-lui une dernière tentative avec un dernier indice, ou de cliquer \"afficher la correction\"."
        },
        cap_open: ->(_at, _b) {
          "Donne le résultat avec le raisonnement complet en 1-2 phrases."
        }
      }
    }.freeze

    def self.for(signal:, answer_type:, budget:)
      sym_signal = signal.to_sym
      sym_at     = answer_type.to_sym

      # chip_resultat is special: cap-aware
      if sym_signal == :chip_resultat
        cap_locked = budget[:attempts_count].to_i < 2 && !budget[:viewed_correction]
        key = cap_locked ? :cap_locked : :cap_open
        return HINTS[:chip_resultat][key].call(sym_at, budget)
      end

      entry = HINTS[sym_signal]
      return DEFAULT_FALLBACK unless entry

      hint =
        if entry.is_a?(Hash)
          entry[sym_at] || entry.values.first
        else
          entry
        end

      # All entries are now lambdas with arity 2: (answer_type_or_unused, budget)
      hint.is_a?(Proc) ? hint.call(sym_at, budget) : hint.to_s
    end
  end
end
```

- [ ] **Step 4: Run to verify pass**

Run: `bundle exec rspec spec/services/tutor/behavior_hints_spec.rb`
Expected: 5 examples, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add app/services/tutor/behavior_hints.rb spec/services/tutor/behavior_hints_spec.rb
git commit -m "feat(tutor): add BehaviorHints static mapping

(signal, answer_type, budget) → hint string. Used by BuildContext for the
ACTION ATTENDUE block. Cap-locked vs cap-open variants for chip_resultat."
```

---

### Task 8: `Tutor::Classify` (LLM classifier post-response)

**Files:**
- Create: `app/services/tutor/classify.rb`
- Create: `spec/services/tutor/classify_spec.rb`

- [ ] **Step 1: Write the failing spec**

```ruby
require "rails_helper"

RSpec.describe Tutor::Classify do
  describe ".call" do
    let(:tutor_message) { "Bien, tu tiens la formule. Repère la consommation au 100km dans DT1." }
    let(:answer_type)   { "calcul" }

    before do
      stub_const("ENV", ENV.to_hash.merge("ANTHROPIC_API_KEY" => "test-key"))
    end

    context "when the LLM returns valid JSON" do
      it "returns the parsed annotation" do
        stub_anthropic_response(<<~JSON)
          {
            "gives_formula": true,
            "gives_value": false,
            "gives_calculation": false,
            "gives_result": false,
            "validates_attempt": false,
            "marks_done": false,
            "concepts": ["consommation totale"]
          }
        JSON

        result = described_class.call(tutor_message: tutor_message, answer_type: answer_type)

        expect(result.ok?).to be(true)
        expect(result.value[:annotation]["gives_formula"]).to be(true)
        expect(result.value[:annotation]["concepts"]).to eq(["consommation totale"])
      end
    end

    context "when JSON is malformed" do
      it "returns a neutral annotation without raising" do
        stub_anthropic_response("not json at all")

        result = described_class.call(tutor_message: tutor_message, answer_type: answer_type)

        expect(result.ok?).to be(true)  # neutral, never blocking
        expect(result.value[:annotation]).to eq(Tutor::Classify::NEUTRAL_ANNOTATION)
        expect(result.value[:warning]).to match(/malformed/i)
      end
    end

    context "when the call times out" do
      it "returns a neutral annotation" do
        allow_any_instance_of(described_class).to receive(:call_anthropic)
          .and_raise(Net::ReadTimeout.new("timeout"))

        result = described_class.call(tutor_message: tutor_message, answer_type: answer_type)

        expect(result.ok?).to be(true)
        expect(result.value[:annotation]).to eq(Tutor::Classify::NEUTRAL_ANNOTATION)
      end
    end

    context "when ANTHROPIC_API_KEY is missing" do
      before { stub_const("ENV", ENV.to_hash.merge("ANTHROPIC_API_KEY" => nil)) }

      it "returns a neutral annotation and logs a warning" do
        expect(Rails.logger).to receive(:warn).with(/missing.*ANTHROPIC_API_KEY/i)

        result = described_class.call(tutor_message: tutor_message, answer_type: answer_type)

        expect(result.ok?).to be(true)
        expect(result.value[:annotation]).to eq(Tutor::Classify::NEUTRAL_ANNOTATION)
      end
    end
  end

  def stub_anthropic_response(content)
    fake = double("anthropic_chat",
      ask: double("response", content: content,
                  input_tokens: 100, output_tokens: 50))
    allow_any_instance_of(described_class).to receive(:build_anthropic_client).and_return(fake)
  end
end
```

- [ ] **Step 2: Run to verify failure**

Run: `bundle exec rspec spec/services/tutor/classify_spec.rb`
Expected: FAIL.

- [ ] **Step 3: Implement the service**

Create `app/services/tutor/classify.rb`:

```ruby
module Tutor
  # Inline post-response classifier (haiku 4.5 on the server-side
  # ANTHROPIC_API_KEY). Reads the tutor message and returns a JSON
  # annotation of what the tutor just did.
  #
  # Robustness: malformed JSON, timeout, rate limit, missing key → neutral
  # annotation, no retry. The next turn's budget will self-correct via the
  # explicit counters in the prompt.
  class Classify
    MODEL                  = "claude-haiku-4-5-20251001".freeze
    DEFAULT_TEMPERATURE    = 0
    DEFAULT_MAX_TOKENS     = 200
    PROMPT_FILE            = Rails.root.join("config", "prompts", "tutor_classifier.txt").freeze

    NEUTRAL_ANNOTATION = {
      "gives_formula"     => false,
      "gives_value"       => false,
      "gives_calculation" => false,
      "gives_result"      => false,
      "validates_attempt" => false,
      "marks_done"        => false,
      "concepts"          => []
    }.freeze

    def self.call(tutor_message:, answer_type:)
      new(tutor_message: tutor_message, answer_type: answer_type).call
    end

    def initialize(tutor_message:, answer_type:)
      @tutor_message = tutor_message.to_s
      @answer_type   = answer_type.to_s
    end

    def call
      api_key = ENV["ANTHROPIC_API_KEY"]
      if api_key.blank?
        Rails.logger.warn("[Tutor::Classify] missing ANTHROPIC_API_KEY, using neutral annotation")
        return Result.ok(annotation: NEUTRAL_ANNOTATION, warning: "missing key")
      end

      raw = call_anthropic(api_key)
      parsed = parse_json(raw)

      if parsed.nil?
        Rails.logger.warn("[Tutor::Classify] malformed JSON, using neutral annotation. raw=#{raw.inspect}")
        return Result.ok(annotation: NEUTRAL_ANNOTATION, warning: "malformed JSON")
      end

      Result.ok(annotation: NEUTRAL_ANNOTATION.merge(parsed.slice(*NEUTRAL_ANNOTATION.keys)))
    rescue Net::ReadTimeout, Net::OpenTimeout, Errno::ETIMEDOUT => e
      Rails.logger.warn("[Tutor::Classify] timeout: #{e.message}")
      Result.ok(annotation: NEUTRAL_ANNOTATION, warning: "timeout")
    rescue => e
      Rails.logger.warn("[Tutor::Classify] error: #{e.class.name}: #{e.message}")
      Result.ok(annotation: NEUTRAL_ANNOTATION, warning: "error")
    end

    private

    def call_anthropic(api_key)
      client = build_anthropic_client(api_key)
      prompt = build_prompt
      resp   = client.ask(prompt)
      resp.respond_to?(:content) ? resp.content.to_s : resp.to_s
    end

    def build_anthropic_client(api_key = ENV["ANTHROPIC_API_KEY"])
      RubyLLM.configure { |c| c.anthropic_api_key = api_key }
      chat = RubyLLM::Chat.new(model: MODEL)
      chat.with_params(temperature: DEFAULT_TEMPERATURE, max_tokens: DEFAULT_MAX_TOKENS)
      chat
    end

    def build_prompt
      <<~PROMPT
        Tu reçois le message d'un tuteur à un élève préparant le BAC STI2D, sur une question de type #{@answer_type}.
        Identifie ce que le tuteur vient de faire dans ce message.

        Réponds en JSON strict avec ces booléens :
        - gives_formula     : le tuteur énonce une formule, méthode, ou structure de réponse ?
        - gives_value       : le tuteur révèle une valeur précise du sujet (chiffre, donnée DT) ?
        - gives_calculation : le tuteur détaille un calcul étape par étape (avec chiffres) ?
        - gives_result      : le tuteur révèle le résultat final attendu de la question ?
        - validates_attempt : le tuteur confirme/rejette explicitement une tentative de l'élève ?
        - marks_done        : le tuteur indique que la question est résolue / passe à autre chose ?

        Et un array :
        - concepts : liste des concepts disciplinaires mentionnés (ex. ["conductivité thermique"])

        Réponds uniquement le JSON, rien d'autre.

        Message tuteur : """#{@tutor_message}"""
      PROMPT
    end

    def parse_json(raw)
      stripped = raw.to_s.strip
      stripped = stripped.sub(/\A```(?:json)?\s*/, "").sub(/\s*```\z/, "")
      JSON.parse(stripped)
    rescue JSON::ParserError
      nil
    end
  end
end
```

- [ ] **Step 4: Run to verify pass**

Run: `bundle exec rspec spec/services/tutor/classify_spec.rb`
Expected: 4 examples, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add app/services/tutor/classify.rb spec/services/tutor/classify_spec.rb
git commit -m "feat(tutor): add Classify post-response annotator

Inline classifier on server ANTHROPIC_API_KEY (haiku 4.5, JSON strict).
Robust to malformed JSON / timeout / missing key — returns neutral
annotation, never blocks the chat. The next turn's budget self-corrects
via explicit counters in the prompt."
```

---

### Task 9: `Tutor::BroadcastDone` (final payload with chips)

**Files:**
- Create: `app/services/tutor/broadcast_done.rb`
- Modify: `app/services/tutor/broadcast_message.rb` (split: keep streaming-related logic only or remove if redundant)
- Create: `spec/services/tutor/broadcast_done_spec.rb`

- [ ] **Step 1: Write the failing spec**

```ruby
require "rails_helper"

RSpec.describe Tutor::BroadcastDone do
  let(:student) { create(:student) }
  let(:subject_record) { create(:subject) }
  let(:question) { create(:question, part: create(:part, subject: subject_record), answer_type: "calcul") }
  let(:conversation) { create(:conversation, student: student, subject: subject_record) }
  let(:assistant_message) { create(:message, conversation: conversation, role: :assistant, content: "Salut.", question: question) }

  describe ".call" do
    it "broadcasts a done payload with message and chips_html" do
      expect(ActionCable.server).to receive(:broadcast).with(
        "conversation_#{conversation.id}",
        hash_including(type: "done", message: hash_including(id: assistant_message.id), chips_html: be_a(String))
      )

      result = described_class.call(
        conversation: conversation,
        message:      assistant_message,
        question:     question,
        access_code:  "tutor-sim"
      )
      expect(result.ok?).to be(true)
    end

    it "is resilient to chips render errors (returns ok with empty chips_html)" do
      allow(ApplicationController.renderer).to receive(:render).and_raise("render boom")
      expect(ActionCable.server).to receive(:broadcast).with(
        anything,
        hash_including(chips_html: "")
      )

      described_class.call(conversation: conversation, message: assistant_message,
                           question: question, access_code: "tutor-sim")
    end
  end
end
```

- [ ] **Step 2: Run to verify failure**

Run: `bundle exec rspec spec/services/tutor/broadcast_done_spec.rb`
Expected: FAIL.

- [ ] **Step 3: Implement the service**

Create `app/services/tutor/broadcast_done.rb`:

```ruby
module Tutor
  # Broadcasts the final ActionCable payload for a tutor turn:
  # - message metadata (id, role, content, streaming_finished_at)
  # - chips_html rendered from current trace + answer_type
  # Streaming chunks themselves are sent by Tutor::CallLlm directly.
  class BroadcastDone
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
      return "" unless @question && @access_code.present?

      ApplicationController.renderer.render(
        partial: "student/conversations/chips",
        locals:  {
          conversation: @conversation,
          question:     @question,
          access_code:  @access_code,
          chips:        chips_for_view
        }
      )
    rescue => e
      Rails.logger.error("[Tutor::BroadcastDone] chips render failed: #{e.message}")
      ""
    end

    def chips_for_view
      trace = @conversation.tutor_state.trace_for(@question.id)
      Tutor::ChipsPresenter.call(
        trace:          trace,
        answer_type:    @question.answer_type.to_s,
        expected_value: nil  # could be wired later if structured_correction has a numeric final
      )
    end
  end
end
```

- [ ] **Step 4: Update `_chips.html.erb` to consume the new chip shape**

Modify `app/views/student/conversations/_chips.html.erb` so it renders:
- Each chip as a button with `data-chip-action="<action>"`, `data-chip-payload="<payload>"`, optional `disabled` attribute and `title="<tooltip>"`.

If the file currently expects the old shape (label/text/color/disabled/level), replace its content so it iterates `chips` from locals (passed by BroadcastDone) and outputs the new structure. Keep the styling classes (`bg-rad-warm`, `border`, `text-rad-text`) consistent with the Radical reskin.

Example minimal partial (adjust styling to match existing reskin):

```erb
<%# Locals: conversation, question, access_code, chips: Array<Hash> %>
<turbo-frame id="tutor-chips" class="flex flex-wrap gap-2 px-3 py-2">
  <% Array(chips).each do |chip| %>
    <% disabled = chip[:disabled] %>
    <button type="button"
            data-action="click->tutor-chat#handleChipClick"
            data-chip-action="<%= chip[:action] %>"
            data-chip-payload="<%= chip[:payload].to_s %>"
            <%= "disabled" if disabled %>
            <% if disabled && chip[:tooltip].present? %>
              title="<%= chip[:tooltip] %>"
            <% end %>
            class="px-3 py-1.5 rounded-full border border-rad-rule bg-rad-warm text-rad-text text-sm
                   <%= 'opacity-50 cursor-not-allowed' if disabled %>">
      <%= chip[:label] %>
    </button>
  <% end %>
</turbo-frame>
```

- [ ] **Step 5: Run to verify pass**

Run: `bundle exec rspec spec/services/tutor/broadcast_done_spec.rb`
Expected: 2 examples, 0 failures.

- [ ] **Step 6: Commit**

```bash
git add app/services/tutor/broadcast_done.rb spec/services/tutor/broadcast_done_spec.rb \
        app/views/student/conversations/_chips.html.erb
git commit -m "feat(tutor): add BroadcastDone with chips_html and new chip view

Splits the final payload broadcaster from the streaming chunks. _chips.html.erb
consumes the new chip shape (action/label/payload/disabled/tooltip)."
```

---

## Phase 3 — System prompt + orchestration

### Task 10: Rewrite `Tutor::BuildContext` for the 6-block prompt

**Files:**
- Modify: `app/services/tutor/build_context.rb` (full rewrite)
- Modify: `spec/services/tutor/build_context_spec.rb` (full rewrite)

- [ ] **Step 1: Write the failing spec**

Replace `spec/services/tutor/build_context_spec.rb` with:

```ruby
require "rails_helper"

RSpec.describe Tutor::BuildContext do
  let(:student) { create(:student) }
  let(:subject_record) { create(:subject, title: "Ferme éolienne 2025", presentation_text: "Mise en situation…") }
  let(:part) { create(:part, subject: subject_record, title: "Partie 1", objective_text: "Comparer modes de transport.") }
  let(:question) do
    create(:question,
      part: part,
      number: "1.2",
      label: "Calculer la consommation totale.",
      answer_type: "calcul")
  end
  let(:answer) do
    create(:answer, question: question, correction_text: "Car = 56,73 l",
      structured_correction: {
        "input_data"         => [{ "name" => "consommation", "value" => "30,5 l/100km", "source" => "DT1" }],
        "intermediate_steps" => ["Identifier consommation et distance", "Multiplier × distance / 100"],
        "final_answers"      => [{ "name" => "Conso totale", "value" => "56,73 L", "reasoning" => "30,5 × 186 / 100" }]
      })
  end

  let(:conversation) do
    create(:conversation, student: student, subject: subject_record,
                          tutor_state: TutorState.default.with(current_question_id: question.id))
  end

  describe ".call" do
    it "produces a system_prompt with the 6 expected blocks" do
      result = described_class.call(
        conversation:  conversation,
        question:      question,
        student_input: "Je ne comprends pas",
        last_signal:   :dont_understand
      )

      expect(result.ok?).to be(true)
      prompt = result.value[:system_prompt]
      expect(prompt).to match(/POSTURE/)
      expect(prompt).to match(/CONTEXTE QUESTION/)
      expect(prompt).to match(/CORRECTION STRUCTURÉE/)
      expect(prompt).to match(/ÉTAT D'AIDE/)
      expect(prompt).to match(/CAP RÉSULTAT/)
      expect(prompt).to match(/ACTION ATTENDUE/)
    end

    it "exposes the budget with explicit counters" do
      result = described_class.call(conversation: conversation, question: question,
                                    student_input: "test", last_signal: :dont_understand)
      prompt = result.value[:system_prompt]
      expect(prompt).to match(/Formule.*donnée\s*:\s*NON/i)
      expect(prompt).to match(/Tentatives.*0/)
    end

    it "formulates the cap in positive form (OU)" do
      result = described_class.call(conversation: conversation, question: question,
                                    student_input: "test", last_signal: :dont_understand)
      prompt = result.value[:system_prompt]
      expect(prompt).to match(/tentatives\s*≥\s*2\s+OU\s+correction\s+vue/i)
    end

    it "injects the calibrated behavior_hint for the given signal+answer_type" do
      result = described_class.call(conversation: conversation, question: question,
                                    student_input: "Je ne comprends pas", last_signal: :dont_understand)
      prompt = result.value[:system_prompt]
      expect(prompt).to match(/Démarre direct/)
      expect(prompt).to match(/sous-tâche|formule/)
    end

    it "instructs the LLM to greet briefly when greeted is false" do
      result = described_class.call(conversation: conversation, question: question,
                                    student_input: nil, last_signal: :fresh_open)
      prompt = result.value[:system_prompt]
      expect(prompt).to match(/Salue brièvement/)
    end

    it "removes legacy 049 patterns" do
      result = described_class.call(conversation: conversation, question: question,
                                    student_input: "test", last_signal: :dont_understand)
      prompt = result.value[:system_prompt]

      expect(prompt).not_to match(/socratique/i)
      expect(prompt).not_to match(/70\s*%/)
      expect(prompt).not_to match(/verbe d'action/i)
      expect(prompt).not_to match(/spotting_type|spotting_data|guiding|validating/)
      expect(prompt).not_to match(/Indices.*1.*5/)
    end
  end
end
```

- [ ] **Step 2: Run to verify failure**

Run: `bundle exec rspec spec/services/tutor/build_context_spec.rb`
Expected: FAIL.

- [ ] **Step 3: Replace `app/services/tutor/build_context.rb`**

```ruby
module Tutor
  # 062: assembles the system prompt in 6 blocks.
  # Posture / Contexte question / Correction structurée / État d'aide /
  # Cap résultat final / Action attendue (with behavior_hint).
  class BuildContext
    MESSAGE_LIMIT = 40

    POSTURE = <<~POSTURE.freeze
      [POSTURE]
      Tu es un prof de STI2D qui aide un élève à réussir un sujet de BAC.
      Tu tutoies, tu es bienveillant, sympa, direct, sans détour.
      Pas familier-camarade, pas formel-distant. Tu parles court : 1-3 phrases par message.

      Tu peux donner les concepts, formules, méthodes, valeurs et calculs. Ton objectif est
      que l'élève réussisse cette question, pas qu'il devine seul. Mais à chaque palier,
      propose-lui d'essayer avant de donner. Quand l'élève bloque, demande où exactement,
      et donne juste ce qu'il faut pour qu'il puisse continuer.
    POSTURE

    def self.call(conversation:, question:, student_input:, last_signal:)
      new(conversation: conversation, question: question,
          student_input: student_input, last_signal: last_signal).call
    end

    def initialize(conversation:, question:, student_input:, last_signal:)
      @conversation  = conversation
      @question      = question
      @student_input = student_input
      @last_signal   = last_signal
    end

    def call
      prompt = +""
      prompt << POSTURE
      prompt << build_context_block
      prompt << build_correction_block
      prompt << build_budget_block
      prompt << build_cap_block
      prompt << build_action_block

      messages = @conversation.messages
                              .where(question_id: @question.id)
                              .order(:created_at)
                              .last(MESSAGE_LIMIT)
                              .map { |m| { role: m.role, content: m.content } }

      Result.ok(system_prompt: prompt, messages: messages)
    end

    private

    def trace
      @trace ||= @conversation.tutor_state.trace_for(@question.id)
    end

    def budget
      @budget ||= trace.budget
    end

    def build_context_block
      part = @question.part
      subject = @conversation.subject

      <<~CTX

        [CONTEXTE QUESTION]
        Spécialité : #{subject.specialty}
        Sujet : #{subject.title}
        Partie #{part.number} — #{part.title}
        Objectif de la partie : #{part.objective_text.to_s}

        Question #{@question.number} (#{@question.answer_type}) : #{@question.label}
        Contexte local : #{@question.context_text.to_s}
      CTX
    end

    def build_correction_block
      sc = @question.answer&.structured_correction
      return "" if sc.blank?

      block = +"\n[CORRECTION STRUCTURÉE]\n"

      inputs = Array(sc["input_data"])
      if inputs.any?
        block << "\n[DONNÉES DU SUJET — TU PEUX LES CITER LIBREMENT]\n"
        inputs.each do |d|
          block << "- #{d['name']} : #{d['value']} [#{d['source']}]\n"
        end
      end

      steps = Array(sc["intermediate_steps"])
      if steps.any?
        block << "\n[ÉTAPES DE RAISONNEMENT ATTENDUES]\n"
        steps.each_with_index { |s, i| block << "#{i + 1}. #{s}\n" }
      end

      finals = Array(sc["final_answers"])
      if finals.any?
        block << "\n[RÉSULTAT FINAL — VOIR CAP CI-DESSOUS]\n"
        finals.each do |f|
          block << "- #{f['name']} = #{f['value']}\n"
          block << "  (raisonnement attendu : #{f['reasoning']})\n" if f["reasoning"].present?
        end
      end

      errors = Array(sc["common_errors"])
      if errors.any?
        block << "\n[ERREURS FRÉQUENTES À SURVEILLER]\n"
        errors.each do |e|
          block << "- #{e['error']}\n"
          block << "  → #{e['remediation']}\n" if e["remediation"].present?
        end
      end

      block
    end

    def build_budget_block
      <<~BUDGET

        [ÉTAT D'AIDE]
        - Formule/méthode donnée   : #{yes_no(budget[:formule_given])}
        - Valeurs identifiées      : #{yes_no(budget[:value_given])}
        - Calcul détaillé donné    : #{yes_no(budget[:calc_given])}
        - Résultat final révélé    : #{yes_no(budget[:result_given])}
        - Tentatives de l'élève    : #{budget[:attempts_count]}
        - Correction vue par l'élève : #{yes_no(budget[:viewed_correction])}

        Adapte ta réponse en fonction. Ne re-donne pas ce qui est déjà donné. Pousse l'élève
        sur le palier suivant.
      BUDGET
    end

    def build_cap_block
      <<~CAP

        [CAP RÉSULTAT FINAL]
        Tu peux donner le résultat final si :
        - l'élève a déjà fait ≥ 2 tentatives, OU
        - l'élève a déjà vu la correction.

        Sinon, refuse de le donner. Si l'élève le demande quand même :
        propose-lui une dernière tentative avec un dernier indice,
        ou de cliquer "afficher la correction" sur la page.
      CAP
    end

    def build_action_block
      hint = BehaviorHints.for(
        signal:      @last_signal || :default,
        answer_type: @question.answer_type.to_s,
        budget:      budget
      )

      summary = build_signal_summary

      <<~ACT

        [ACTION ATTENDUE]
        #{summary}

        Comportement attendu :
        #{hint}
      ACT
    end

    def build_signal_summary
      case @last_signal
      when :fresh_open
        "L'élève vient d'ouvrir le drawer pour la première fois sur ce sujet."
      when :opened_after_data_hints
        "L'élève vient de cliquer 'afficher data_hints' sur la page question."
      when :opened_after_correction
        "L'élève vient de cliquer 'afficher la correction' sur la page question."
      when :navigation_arrival
        if budget[:attempts_count].positive?
          "L'élève revient sur cette question (déjà entamée — #{budget[:attempts_count]} tentative(s))."
        else
          "L'élève arrive sur cette question pour la première fois."
        end
      when :wrong_attempt
        "L'élève vient de faire une tentative incorrecte. Contenu : #{@student_input.to_s.strip}."
      when :correct_attempt
        "L'élève vient de faire une tentative correcte."
      when :dont_understand
        "L'élève vient d'écrire qu'il ne comprend pas / bloque (\"#{@student_input.to_s.strip}\")."
      when :chip_formule, :chip_valeur, :chip_calcul, :chip_resultat
        "L'élève vient de cliquer le chip #{@last_signal.to_s.sub(/^chip_/, '').upcase} dans le drawer."
      else
        "Message élève : \"#{@student_input.to_s.strip}\"."
      end
    end

    def yes_no(value)
      value ? "OUI" : "NON"
    end
  end
end
```

- [ ] **Step 4: Run to verify pass**

Run: `bundle exec rspec spec/services/tutor/build_context_spec.rb`
Expected: 6 examples, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add app/services/tutor/build_context.rb spec/services/tutor/build_context_spec.rb
git commit -m "feat(tutor): rewrite BuildContext for 6-block 062 prompt

POSTURE / CONTEXTE QUESTION / CORRECTION STRUCTURÉE / ÉTAT D'AIDE /
CAP RÉSULTAT FINAL / ACTION ATTENDUE. Cap formulated in positive form
(OU on the lift). Removes 049 patterns (socratic, 70%, verbe d'action,
indices 1-5)."
```

---

### Task 11: Rewrite `Tutor::ProcessMessage` orchestrator

**Files:**
- Modify: `app/services/tutor/process_message.rb` (full rewrite)
- Modify: `app/services/tutor/call_llm.rb` (remove `with_tools(...)` references)
- Modify: `spec/services/tutor/process_message_spec.rb` (full rewrite)
- Modify: `spec/services/tutor/call_llm_spec.rb` (drop tool-related expectations)

- [ ] **Step 1: Remove tool wiring from `Tutor::CallLlm`**

In `app/services/tutor/call_llm.rb`, replace the block:

```ruby
chat.with_tools(
  Tutor::Tools::TransitionTool,
  Tutor::Tools::UpdateLearnerModelTool,
  Tutor::Tools::RequestHintTool,
  Tutor::Tools::EvaluateSpottingTool
)
chat.on_tool_call { |tc| tool_calls << tc }
```

with:

```ruby
# 062: prose pure — pas de tool-use forcé.
# Le classifier post-réponse (Tutor::Classify) annote la trace.
```

And in the `response = chat.ask(...)` block, drop the `if chunk.tool_calls.present? ...` branch and remove the `tool_calls` from the `Result.ok(...)` payload (return only `full_content:`).

The simplified return:

```ruby
Result.ok(full_content: full_content)
```

- [ ] **Step 2: Update `spec/services/tutor/call_llm_spec.rb`**

Drop tool-related assertions in existing examples. The spec should now cover:
- successful streaming with chunks broadcast
- error paths (NoApiKeyError, generic error)
- absence of tool wiring (don't assert on `tool_calls`).

- [ ] **Step 3: Write the new ProcessMessage spec**

Replace `spec/services/tutor/process_message_spec.rb` with:

```ruby
require "rails_helper"

RSpec.describe Tutor::ProcessMessage do
  let(:student) { create(:student) }
  let(:subject_record) { create(:subject) }
  let(:part) { create(:part, subject: subject_record) }
  let(:question) { create(:question, part: part, answer_type: "calcul") }
  let!(:answer) { create(:answer, question: question, structured_correction: { "input_data" => [], "final_answers" => [] }) }
  let(:conversation) { create(:conversation, student: student, subject: subject_record) }

  before do
    allow(Tutor::CallLlm).to receive(:call).and_return(
      Tutor::Result.ok(full_content: "Bien, prends la formule λS·ΔT/e.")
    )
    allow(Tutor::Classify).to receive(:call).and_return(
      Tutor::Result.ok(annotation: { "gives_formula" => true, "concepts" => ["conductivité"] })
    )
    allow(Tutor::BroadcastDone).to receive(:call).and_return(Tutor::Result.ok)
  end

  it "validates input, records the student attempt, calls LLM, classifies, records tutor events, broadcasts" do
    result = described_class.call(
      conversation:  conversation,
      student_input: "5673",
      question:      question,
      access_code:   "tutor-sim"
    )

    expect(result.ok?).to be(true)
    expect(Tutor::CallLlm).to have_received(:call)
    expect(Tutor::Classify).to have_received(:call)
    expect(Tutor::BroadcastDone).to have_received(:call)

    conversation.reload
    trace = conversation.tutor_state.trace_for(question.id)
    types = trace.events.map { |e| e["type"] }

    expect(types).to include("student_attempt")
    expect(types).to include("tutor_gave")  # because gives_formula was true
    expect(conversation.tutor_state.concepts_seen).to include("conductivité")
  end

  it "marks greeted=true after the first turn" do
    expect(conversation.tutor_state.greeted).to be(false)
    described_class.call(conversation: conversation, student_input: "Salut",
                         question: question, access_code: "tutor-sim")
    expect(conversation.reload.tutor_state.greeted).to be(true)
  end

  it "records cap_violation when classifier reports gives_result while cap is active" do
    allow(Tutor::Classify).to receive(:call).and_return(
      Tutor::Result.ok(annotation: { "gives_result" => true, "concepts" => [] })
    )

    described_class.call(conversation: conversation, student_input: "test",
                         question: question, access_code: "tutor-sim")

    types = conversation.reload.tutor_state.trace_for(question.id).events.map { |e| e["type"] }
    expect(types).to include("cap_violation")
  end
end
```

- [ ] **Step 4: Run to verify failure**

Run: `bundle exec rspec spec/services/tutor/process_message_spec.rb`
Expected: FAIL.

- [ ] **Step 5: Replace `app/services/tutor/process_message.rb`**

```ruby
module Tutor
  # 062 orchestrator. One LLM call per turn (streaming), then inline classify
  # post-response, record events, broadcast done.
  #
  # Flow:
  #   ValidateInput → RecordEvent(student_attempt) → BuildContext → CallLlm
  #   → Classify → RecordEvent(tutor_gave / concept_seen / cap_violation)
  #   → BroadcastDone
  class ProcessMessage
    def self.call(conversation:, student_input:, question:, access_code:)
      new(conversation: conversation, student_input: student_input,
          question: question, access_code: access_code).call
    end

    def initialize(conversation:, student_input:, question:, access_code:)
      @conversation  = conversation
      @student_input = student_input
      @question      = question
      @access_code   = access_code
    end

    def call
      validate_result = ValidateInput.call(raw_input: @student_input)
      return validate_result if validate_result.err?

      sanitized_for_llm = validate_result.value[:sanitized_input]
      display_content   = @student_input.to_s.strip

      last_signal = detect_last_signal(display_content)

      if last_signal != :fresh_open
        RecordEvent.call(
          conversation: @conversation,
          question_id:  @question.id,
          type:         "student_attempt",
          source:       "llm_message",
          content:      display_content,
          verdict:      "unknown"  # classifier can update later if it can validate
        )
      end

      @conversation.messages.create!(role: :user, content: display_content, question: @question)
      assistant_msg = @conversation.messages.create!(
        role: :assistant, content: "", question: @question, chunk_index: 0
      )

      context_result = BuildContext.call(
        conversation:  @conversation.reload,
        question:      @question,
        student_input: sanitized_for_llm,
        last_signal:   last_signal
      )
      return context_result if context_result.err?

      llm_result = CallLlm.call(
        conversation:    @conversation,
        system_prompt:   context_result.value[:system_prompt],
        messages:        context_result.value[:messages],
        student_message: assistant_msg
      )
      return llm_result if llm_result.err?

      tutor_text = llm_result.value[:full_content]

      classify_result = Classify.call(tutor_message: tutor_text, answer_type: @question.answer_type.to_s)
      annotation = classify_result.value[:annotation]

      record_tutor_events(annotation)
      mark_greeted_if_needed

      BroadcastDone.call(
        conversation: @conversation.reload,
        message:      assistant_msg,
        question:     @question,
        access_code:  @access_code
      )
    end

    private

    def detect_last_signal(content)
      return :fresh_open if @conversation.tutor_state.greeted == false

      return :chip_formule  if content.include?("Quelle formule")
      return :chip_valeur   if content.include?("Donne-moi les valeurs") || content.include?("Où je trouve les données")
      return :chip_calcul   if content.match?(/refaire le calcul ensemble/)
      return :chip_resultat if content.match?(/résultat final/i)

      :dont_understand
    end

    def record_tutor_events(annotation)
      cap_active = @conversation.tutor_state.trace_for(@question.id).cap_active?

      record_what("formule",  "gives_formula",     annotation)
      record_what("valeur",   "gives_value",       annotation)
      record_what("calcul",   "gives_calculation", annotation)

      if annotation["gives_result"]
        if cap_active
          RecordEvent.call(
            conversation: @conversation,
            question_id:  @question.id,
            type:         "cap_violation",
            source:       "classifier"
          )
        else
          RecordEvent.call(
            conversation: @conversation,
            question_id:  @question.id,
            type:         "tutor_gave",
            source:       "classifier",
            what:         "résultat"
          )
        end
      end

      Array(annotation["concepts"]).each do |c|
        next if c.blank?
        RecordEvent.call(
          conversation: @conversation,
          question_id:  @question.id,
          type:         "concept_seen",
          source:       "classifier",
          concept:      c
        )
      end
    end

    def record_what(what, key, annotation)
      return unless annotation[key]
      RecordEvent.call(
        conversation: @conversation,
        question_id:  @question.id,
        type:         "tutor_gave",
        source:       "classifier",
        what:         what
      )
    end

    def mark_greeted_if_needed
      return if @conversation.tutor_state.greeted

      new_state = @conversation.tutor_state.with(greeted: true)
      @conversation.update!(tutor_state: new_state)
    end
  end
end
```

- [ ] **Step 6: Run to verify pass**

Run: `bundle exec rspec spec/services/tutor/process_message_spec.rb spec/services/tutor/call_llm_spec.rb`
Expected: green.

- [ ] **Step 7: Commit**

```bash
git add app/services/tutor/process_message.rb app/services/tutor/call_llm.rb \
        spec/services/tutor/process_message_spec.rb spec/services/tutor/call_llm_spec.rb
git commit -m "feat(tutor): rewrite ProcessMessage orchestrator + remove tools from CallLlm

ValidateInput → record student_attempt → BuildContext → CallLlm (prose pure)
→ Classify → record tutor_gave/concept_seen/cap_violation → BroadcastDone.
CallLlm no longer registers RubyLLM tools — the classifier annotates instead."
```

---

## Phase 4 — AASM, controllers, routes, drawer

### Task 12: Refactor `Conversation` AASM 5→3 states

**Files:**
- Modify: `app/models/conversation.rb`
- Modify: `spec/models/conversation_aasm_spec.rb`

- [ ] **Step 1: Update the spec**

Replace `spec/models/conversation_aasm_spec.rb` with assertions for the 3-state machine:

```ruby
require "rails_helper"

RSpec.describe Conversation, type: :model do
  describe "AASM (062: 3-state machine)" do
    let(:student_with_key) { create(:student, :with_api_key) }
    let(:student_without_key) { create(:student) }

    let(:subject_record) { create(:subject) }

    it "starts as :disabled" do
      conv = create(:conversation, student: student_with_key, subject: subject_record)
      expect(conv).to be_disabled
    end

    it "transitions disabled → active when student has api_key" do
      conv = create(:conversation, student: student_with_key, subject: subject_record)
      expect(conv.may_activate?).to be(true)
      conv.activate!
      expect(conv).to be_active
    end

    it "guards activation when no api_key and no free mode" do
      conv = create(:conversation, student: student_without_key, subject: subject_record)
      expect { conv.activate! }.to raise_error(AASM::InvalidTransition)
    end

    it "transitions active → done via finish" do
      conv = create(:conversation, student: student_with_key, subject: subject_record).tap(&:activate!)
      conv.finish!
      expect(conv).to be_done
    end

    it "no longer exposes :validating or :feedback states" do
      conv = create(:conversation, student: student_with_key, subject: subject_record)
      expect(conv.aasm.states.map(&:name)).to match_array([:disabled, :active, :done])
    end
  end
end
```

- [ ] **Step 2: Run to verify failure**

Run: `bundle exec rspec spec/models/conversation_aasm_spec.rb`
Expected: FAIL on the new assertions.

- [ ] **Step 3: Replace AASM block in `app/models/conversation.rb`**

```ruby
aasm column: :lifecycle_state do
  state :disabled, initial: true
  state :active
  state :done

  event :activate do
    transitions from: :disabled, to: :active,
                guard: :student_has_api_key_or_free_mode?
  end

  event :finish do
    transitions from: :active, to: :done
  end
end
```

Remove the now-orphaned events `request_validation`, `give_feedback`, `resume`. Remove the corresponding states.

- [ ] **Step 4: Run to verify pass**

Run: `bundle exec rspec spec/models/conversation_aasm_spec.rb`
Expected: 5 examples, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add app/models/conversation.rb spec/models/conversation_aasm_spec.rb
git commit -m "refactor(tutor): simplify Conversation AASM to 3 states (disabled/active/done)

Removes :validating and :feedback states + their events (request_validation /
give_feedback / resume). 062 has no scripted process to enforce."
```

---

### Task 13: Add `student/events` controller and route

**Files:**
- Create: `app/controllers/student/events_controller.rb`
- Modify: `config/routes.rb`
- Create: `spec/requests/student/events_spec.rb`

- [ ] **Step 1: Write the failing request spec**

```ruby
require "rails_helper"

RSpec.describe "Student::Events", type: :request do
  let(:classroom) { create(:classroom) }
  let(:student)   { create(:student, classroom: classroom) }
  let(:subject_record) { create(:subject) }
  let(:question) { create(:question, part: create(:part, subject: subject_record)) }

  before do
    sign_in_student(student, access_code: classroom.access_code)
    create(:classroom_subject, classroom: classroom, subject: subject_record)
  end

  describe "POST /:access_code/events" do
    it "creates an event in the conversation's question_trace" do
      post "/#{classroom.access_code}/events", params: {
        subject_id:  subject_record.id,
        question_id: question.id,
        type:        "viewed_data_hints"
      }

      expect(response).to have_http_status(:no_content)
      conv = Conversation.find_by(student: student, subject: subject_record)
      expect(conv).not_to be_nil
      trace = conv.tutor_state.trace_for(question.id)
      expect(trace.events.last["type"]).to eq("viewed_data_hints")
      expect(trace.events.last["source"]).to eq("page_click")
    end

    it "creates a disabled Conversation silently if none exists yet" do
      expect(Conversation.where(student: student, subject: subject_record)).to be_empty
      post "/#{classroom.access_code}/events", params: {
        subject_id:  subject_record.id,
        question_id: question.id,
        type:        "navigated_here"
      }

      conv = Conversation.find_by(student: student, subject: subject_record)
      expect(conv).not_to be_nil
      expect(conv).to be_disabled
    end

    it "rejects unknown event types" do
      post "/#{classroom.access_code}/events", params: {
        subject_id:  subject_record.id,
        question_id: question.id,
        type:        "totally_unknown"
      }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
```

Note: `sign_in_student` test helper is assumed to exist (cf. existing student spec helpers). If it doesn't, use the same fixture pattern as `spec/requests/student/conversations_spec.rb`.

- [ ] **Step 2: Run to verify failure**

Run: `bundle exec rspec spec/requests/student/events_spec.rb`
Expected: FAIL — no route, no controller.

- [ ] **Step 3: Implement the controller**

Create `app/controllers/student/events_controller.rb`:

```ruby
class Student::EventsController < Student::BaseController
  ALLOWED_TYPES = %w[viewed_data_hints viewed_correction navigated_here].freeze

  def create
    type = params[:type].to_s
    return head :unprocessable_entity unless ALLOWED_TYPES.include?(type)

    subject = Subject.kept.find(params[:subject_id])
    question = Question.kept.find(params[:question_id])

    conversation = ensure_conversation(subject)

    Tutor::RecordEvent.call(
      conversation: conversation,
      question_id:  question.id,
      type:         type,
      source:       "page_click"
    )

    head :no_content
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end

  private

  def ensure_conversation(subject)
    current_student.conversations.find_or_create_by!(subject: subject) do |c|
      c.tutor_state = TutorState.default
    end
  end
end
```

- [ ] **Step 4: Add the route**

In `config/routes.rb`, inside the `scope "/:access_code", as: :student do` block, add:

```ruby
resources :events, only: [ :create ], controller: "student/events"
```

- [ ] **Step 5: Run to verify pass**

Run: `bundle exec rspec spec/requests/student/events_spec.rb`
Expected: 3 examples, 0 failures.

- [ ] **Step 6: Commit**

```bash
git add app/controllers/student/events_controller.rb config/routes.rb \
        spec/requests/student/events_spec.rb
git commit -m "feat(tutor): add Student::EventsController for page-click events

POST /:access_code/events records viewed_data_hints | viewed_correction |
navigated_here events into the conversation's QuestionTrace. Creates a
disabled Conversation silently if none exists yet."
```

---

### Task 14: Update `Student::ConversationsController#create` for silent + simplified flow

**Files:**
- Modify: `app/controllers/student/conversations_controller.rb`
- Modify: `spec/requests/student/conversations_spec.rb`

- [ ] **Step 1: Update the request spec**

Inspect the existing `spec/requests/student/conversations_spec.rb` and adapt: drop assertions on `BuildWelcomeMessage`, `BuildIntroMessage`, `welcome_sent`, `intro_seen`. Add assertions that:
- `create` finds-or-creates the Conversation
- the `tutor_state` is `TutorState.default` for new ones
- the response is a turbo stream replacing `tutor-chat-drawer` when a `question_id` is present

Keep `confidence` action behavior simplified to a no-op or remove if unused. Drop `mark_intro_seen`. Run the spec, verify it fails.

- [ ] **Step 2: Replace controller body**

```ruby
class Student::ConversationsController < Student::BaseController
  before_action :require_api_key, only: [ :create, :messages ]
  before_action :set_conversation, only: [ :messages ]

  def create
    @subject = Subject.kept.find(params[:subject_id])

    @conversation = current_student.conversations.find_or_initialize_by(subject: @subject)
    unless @conversation.persisted?
      @conversation.tutor_state = TutorState.default
      @conversation.save!
    end
    @conversation.activate! unless @conversation.active?

    respond_to do |format|
      format.turbo_stream do
        streams = []
        if params[:question_id].present?
          @question_for_drawer = Question.kept.find_by(id: params[:question_id].to_i)
          streams << turbo_stream.replace(
            "tutor-chat-drawer",
            partial: "student/conversations/drawer",
            locals: {
              conversation: @conversation,
              question:     @question_for_drawer || @subject.questions.first,
              access_code:  params[:access_code]
            }
          )
        else
          streams << turbo_stream.replace(
            "tutor-activation-banner",
            partial: "student/tutor/tutor_activated",
            locals: { subject: @subject, access_code: params[:access_code] }
          )
        end
        render turbo_stream: streams
      end
      format.json { render json: { conversation_id: @conversation.id } }
    end
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Sujet introuvable." }, status: :not_found
  rescue AASM::InvalidTransition => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def messages
    content = params[:content].to_s.strip
    return render json: { error: "Le message ne peut pas être vide." }, status: :unprocessable_entity if content.blank?

    question = Question.kept.find(params[:question_id])
    ProcessTutorMessageJob.perform_later(
      @conversation.id,
      content,
      question.id,
      params[:access_code]
    )

    render json: { status: "ok" }
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Question introuvable." }, status: :not_found
  end

  private

  def set_conversation
    @conversation = current_student.conversations.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Conversation introuvable." }, status: :not_found
  end

  def require_api_key
    ResolveTutorApiKey.new(student: current_student, classroom: current_student.classroom).call
  rescue Tutor::NoApiKeyError
    render json: {
      error: "Configurez votre clé IA dans les réglages, ou demandez à votre enseignant d'activer le mode gratuit.",
      settings_url: student_settings_path(access_code: params[:access_code])
    }, status: :unprocessable_entity
  end
end
```

- [ ] **Step 3: Drop `confidence` and `mark_intro_seen` routes**

In `config/routes.rb` member block of `resources :conversations`, remove:

```ruby
patch :confidence
patch :mark_intro_seen
```

Drop `app/views/student/conversations/_confidence_form.html.erb` and `confidence.turbo_stream.erb` (no longer used).

- [ ] **Step 4: Run all specs**

Run: `bundle exec rspec spec/requests/student/conversations_spec.rb spec/requests/student/events_spec.rb`
Expected: green.

- [ ] **Step 5: Commit**

```bash
git add app/controllers/student/conversations_controller.rb config/routes.rb \
        spec/requests/student/conversations_spec.rb \
        app/views/student/conversations/_confidence_form.html.erb \
        app/views/student/conversations/confidence.turbo_stream.erb
git commit -m "refactor(tutor): simplify ConversationsController for 062 flow

Drop BuildWelcomeMessage / BuildIntroMessage / mark_intro_seen / confidence
mechanics — now handled by the new prompt + classifier + chips. Confidence
form and stream views removed."
```

---

### Task 15: Update drawer (filter by question_id, navigation Option A)

**Files:**
- Modify: `app/views/student/conversations/_drawer.html.erb`
- Modify: `app/views/student/conversations/_message.html.erb` (likely no change but verify)
- Modify: `app/javascript/controllers/tutor_chat_controller.js`
- Create: `spec/features/student_tutor_navigation_spec.rb`

- [ ] **Step 1: Filter messages in the drawer partial**

In `_drawer.html.erb`, find the loop rendering messages. Replace:

```erb
<% conversation.messages.order(:created_at).each do |m| %>
  <%= render "student/conversations/message", message: m %>
<% end %>
```

with:

```erb
<% conversation.messages.where(question_id: question.id).order(:created_at).each do |m| %>
  <%= render "student/conversations/message", message: m %>
<% end %>
```

(If the existing partial uses a different structure, adapt the same predicate.)

- [ ] **Step 2: Wire chip clicks to navigation when `data-chip-action="navigate"`**

In `app/javascript/controllers/tutor_chat_controller.js`, ensure the `handleChipClick` method handles three actions:
- `send` — POST a message with chip's payload
- `navigate` — `window.location.href = chip's payload` (e.g. for `[Question suivante]`)
- `confidence` — kept for backward compat but could be no-op in 062

Also ensure that disabled chips (`disabled` attribute) don't fire any POST — show tooltip only (the browser's native title attribute already handles this; no extra JS needed).

- [ ] **Step 3: Write the navigation feature spec**

```ruby
require "rails_helper"

RSpec.feature "Student tutor — navigation between questions", type: :feature, js: true do
  include FeatureSpecHelpers
  include TutorFeatureHelpers

  let(:classroom) { create(:classroom) }
  let(:student) { create(:student, :with_api_key, classroom: classroom) }
  let(:subject_record) { create(:subject_with_two_questions) }
  let(:q1) { subject_record.parts.first.questions.order(:position).first }
  let(:q2) { subject_record.parts.first.questions.order(:position).second }

  before do
    create(:classroom_subject, classroom: classroom, subject: subject_record)
    FakeRubyLlm.setup_stub
    sign_in_student_via_form(student, access_code: classroom.access_code)
  end

  scenario "drawer follows navigation, filters messages per question" do
    visit student_subject_question_path(access_code: classroom.access_code, subject_id: subject_record.id, id: q1.id)
    open_tutor_drawer

    fill_in "tutor-chat-input", with: "Question 1 message"
    click_button "Envoyer"
    expect(page).to have_content("Question 1 message", wait: 10)

    visit student_subject_question_path(access_code: classroom.access_code, subject_id: subject_record.id, id: q2.id)
    open_tutor_drawer

    expect(page).not_to have_content("Question 1 message")
  end

  scenario "no transition message on rapid back-and-forth without interaction" do
    # Q1: ouverture → message attendu
    visit student_subject_question_path(access_code: classroom.access_code, subject_id: subject_record.id, id: q1.id)
    open_tutor_drawer
    expect(page).to have_selector('[data-tutor-chat-target="message"]', wait: 10)

    initial_count = page.all('[data-tutor-chat-target="message"]').count

    # Q2 → Q1 sans interaction sur Q2 — pas de nouveau message attendu sur Q1
    visit student_subject_question_path(access_code: classroom.access_code, subject_id: subject_record.id, id: q2.id)
    visit student_subject_question_path(access_code: classroom.access_code, subject_id: subject_record.id, id: q1.id)
    sleep 1
    expect(page.all('[data-tutor-chat-target="message"]').count).to eq(initial_count)
  end
end
```

The `subject_with_two_questions` factory needs to exist or be added to `spec/factories/subjects.rb`. If absent, add:

```ruby
factory :subject_with_two_questions, parent: :subject do
  after(:create) do |s|
    p = create(:part, subject: s, position: 1)
    create(:question, part: p, position: 1, number: "1.1", answer_type: "calcul")
    create(:question, part: p, position: 2, number: "1.2", answer_type: "calcul")
  end
end
```

- [ ] **Step 4: Run the feature spec to verify failure**

Run: `bundle exec rspec spec/features/student_tutor_navigation_spec.rb`
Expected: FAIL — drawer probably still shows messages from Q1 on Q2.

- [ ] **Step 5: If needed, fix drawer Stimulus controller for navigation**

Verify that the drawer turbo-frame is correctly replaced on navigation (route `/subjects/:subject_id/questions/:id` should re-render the drawer partial via the question page). If the drawer is in a turbo-frame referenced on each question page, this is already handled by the existing render in `student/questions#show`.

- [ ] **Step 6: Run again, expect green**

Run: `bundle exec rspec spec/features/student_tutor_navigation_spec.rb`
Expected: 2 examples, 0 failures.

- [ ] **Step 7: Commit**

```bash
git add app/views/student/conversations/_drawer.html.erb \
        app/javascript/controllers/tutor_chat_controller.js \
        spec/features/student_tutor_navigation_spec.rb spec/factories/subjects.rb
git commit -m "feat(tutor): drawer follows navigation, messages filtered per question

Drawer renders only messages with question_id == current question.
Stimulus chip handler routes navigate-action chips through window.location.
Disabled chips short-circuit at the DOM level (native disabled attribute)."
```

---

### Task 16: Page-question buttons emit events

**Files:**
- Modify: `app/views/student/questions/show.html.erb` (or wherever the "Afficher correction" / "Afficher data_hints" buttons live)
- Modify: corresponding Stimulus controller (or add inline `data-action` on the buttons)
- Create: `spec/features/student_tutor_events_page_spec.rb`

- [ ] **Step 1: Locate the existing buttons**

Run: `grep -rn "data_hints\|correction" app/views/student/questions/`
Identify the buttons that toggle visibility of the data_hints / correction sections.

- [ ] **Step 2: Add a `data-action` and `fetch` POST on click**

For each button, ensure an event POST is sent. Two approaches:

**Approach A (preferred):** Add a Stimulus controller `student-events` with an action `record(event)`:

```javascript
// app/javascript/controllers/student_events_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String, type: String, subjectId: Number, questionId: Number }

  record(event) {
    fetch(this.urlValue, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector("meta[name=csrf-token]").content
      },
      body: JSON.stringify({
        type:        this.typeValue,
        subject_id:  this.subjectIdValue,
        question_id: this.questionIdValue
      })
    }).catch(err => console.warn("[student-events] failed:", err))
  }
}
```

In `show.html.erb`, wrap each button:

```erb
<button type="button"
        data-controller="student-events"
        data-student-events-url-value="<%= student_events_path(access_code: @access_code) %>"
        data-student-events-type-value="viewed_data_hints"
        data-student-events-subject-id-value="<%= @subject.id %>"
        data-student-events-question-id-value="<%= @question.id %>"
        data-action="click->student-events#record click->reveal#show">
  Afficher data_hints
</button>
```

The existing reveal-on-click logic (probably in another Stimulus controller) keeps working through the chained `data-action`.

- [ ] **Step 3: Write the feature spec**

```ruby
require "rails_helper"

RSpec.feature "Student tutor — events page", type: :feature, js: true do
  include FeatureSpecHelpers
  include TutorFeatureHelpers

  let(:classroom) { create(:classroom) }
  let(:student) { create(:student, :with_api_key, classroom: classroom) }
  let(:subject_record) { create(:subject) }
  let(:question) { create(:question, part: create(:part, subject: subject_record)) }

  before do
    create(:classroom_subject, classroom: classroom, subject: subject_record)
    create(:answer, question: question)  # to enable data_hints button
    FakeRubyLlm.setup_stub
    sign_in_student_via_form(student, access_code: classroom.access_code)
  end

  scenario "clicking 'Afficher data_hints' records the event server-side" do
    visit student_subject_question_path(access_code: classroom.access_code,
                                        subject_id: subject_record.id, id: question.id)
    click_button "Afficher data_hints"

    # poll until the event lands
    Timeout.timeout(10) do
      loop do
        conv = Conversation.find_by(student: student, subject: subject_record)
        break if conv&.tutor_state&.trace_for(question.id)&.events&.any? { |e| e["type"] == "viewed_data_hints" }
        sleep 0.2
      end
    end

    conv = Conversation.find_by(student: student, subject: subject_record)
    types = conv.tutor_state.trace_for(question.id).events.map { |e| e["type"] }
    expect(types).to include("viewed_data_hints")
  end
end
```

- [ ] **Step 4: Run the spec**

Run: `bundle exec rspec spec/features/student_tutor_events_page_spec.rb`
Expected: green.

- [ ] **Step 5: Commit**

```bash
git add app/javascript/controllers/student_events_controller.js \
        app/views/student/questions/show.html.erb \
        spec/features/student_tutor_events_page_spec.rb
git commit -m "feat(tutor): page-question buttons emit events to RecordEvent

Stimulus controller student-events POSTs to /:access_code/events on click,
chained with the existing reveal controller. The conversation is created
silently if none exists yet."
```

---

### Task 17: Cap-active chip greyed feature spec

**Files:**
- Create: `spec/features/student_tutor_cap_results_spec.rb`

- [ ] **Step 1: Write the feature spec**

```ruby
require "rails_helper"

RSpec.feature "Student tutor — cap on final result", type: :feature, js: true do
  include FeatureSpecHelpers
  include TutorFeatureHelpers

  let(:classroom) { create(:classroom) }
  let(:student) { create(:student, :with_api_key, classroom: classroom) }
  let(:subject_record) { create(:subject) }
  let(:question) { create(:question, part: create(:part, subject: subject_record), answer_type: "calcul") }

  before do
    create(:classroom_subject, classroom: classroom, subject: subject_record)
    create(:answer, question: question, structured_correction: { "input_data" => [], "final_answers" => [] })
    FakeRubyLlm.setup_stub
    sign_in_student_via_form(student, access_code: classroom.access_code)
  end

  scenario "Donne le résultat chip is disabled when cap is active" do
    visit student_subject_question_path(access_code: classroom.access_code,
                                        subject_id: subject_record.id, id: question.id)
    open_tutor_drawer

    expect(page).to have_button("Donne le résultat", disabled: true, wait: 15)
  end

  scenario "Donne le résultat chip becomes enabled after viewing correction" do
    visit student_subject_question_path(access_code: classroom.access_code,
                                        subject_id: subject_record.id, id: question.id)

    click_button "Afficher la correction"
    sleep 1
    open_tutor_drawer

    # After viewed_correction, cap is lifted
    # Note: chips refresh requires a tutor turn or chip refresh; in 062 the
    # spec asserts via DOM state after re-render.
    expect(page).to have_button("Donne le résultat", disabled: false, wait: 15)
  end
end
```

- [ ] **Step 2: Run the spec**

Run: `bundle exec rspec spec/features/student_tutor_cap_results_spec.rb`
Expected: green if Tasks 6+13+15+16 are correctly wired.

- [ ] **Step 3: Commit**

```bash
git add spec/features/student_tutor_cap_results_spec.rb
git commit -m "test(tutor): cap result chip enabled/disabled feature spec

Verifies Donne le résultat chip is disabled when cap active (0 attempts +
correction not viewed), and enabled after viewing correction."
```

---

## Phase 5 — Cleanup, cross-provider, simulation

### Task 18: Delete legacy services and tools

**Files (DELETE):**
- `app/services/tutor/apply_tool_calls.rb`
- `app/services/tutor/parse_tool_calls.rb`
- `app/services/tutor/filter_spotting_output.rb`
- `app/services/tutor/inject_data_hints.rb`
- `app/services/tutor/update_tutor_state.rb`
- `app/services/tutor/build_intro_message.rb`
- `app/services/tutor/build_welcome_message.rb`
- `app/services/tutor/tools/` (all 4)
- `spec/services/tutor/apply_tool_calls_spec.rb`
- `spec/services/tutor/parse_tool_calls_spec.rb`
- `spec/services/tutor/filter_spotting_output_spec.rb`
- `spec/services/tutor/inject_data_hints_spec.rb`
- `spec/services/tutor/update_tutor_state_spec.rb`
- `spec/services/tutor/build_intro_message_spec.rb`
- `spec/services/tutor/build_welcome_message_spec.rb`
- `spec/services/tutor/tools/`
- `spec/features/student_tutor_spotting_spec.rb`

- [ ] **Step 1: Delete files**

```bash
git rm app/services/tutor/apply_tool_calls.rb \
       app/services/tutor/parse_tool_calls.rb \
       app/services/tutor/filter_spotting_output.rb \
       app/services/tutor/inject_data_hints.rb \
       app/services/tutor/update_tutor_state.rb \
       app/services/tutor/build_intro_message.rb \
       app/services/tutor/build_welcome_message.rb
git rm -r app/services/tutor/tools/
git rm spec/services/tutor/apply_tool_calls_spec.rb \
       spec/services/tutor/parse_tool_calls_spec.rb \
       spec/services/tutor/filter_spotting_output_spec.rb \
       spec/services/tutor/inject_data_hints_spec.rb \
       spec/services/tutor/update_tutor_state_spec.rb \
       spec/services/tutor/build_intro_message_spec.rb \
       spec/services/tutor/build_welcome_message_spec.rb
git rm -r spec/services/tutor/tools/
git rm spec/features/student_tutor_spotting_spec.rb
```

- [ ] **Step 2: Run full suite, expect green**

Run: `bundle exec rspec`
Expected: 0 failures. Any remaining failure is a regression introduced earlier — fix before commit.

- [ ] **Step 3: Commit**

```bash
git commit -m "refactor(tutor): remove 049 legacy services and tools

ApplyToolCalls / ParseToolCalls / FilterSpottingOutput / InjectDataHints /
UpdateTutorState / BuildIntroMessage / BuildWelcomeMessage and 4 RubyLLM
tools (transition / request_hint / evaluate_spotting / update_learner_model)
removed. All tied specs deleted."
```

---

### Task 19: Cross-provider integration spec

**Files:**
- Create: `spec/services/tutor/cross_provider_spec.rb`

- [ ] **Step 1: Write the cross-provider spec**

```ruby
require "rails_helper"

# 062 invariant: no hard dependency on Anthropic in the main tutor path.
# Classifier uses the server-side ANTHROPIC_API_KEY by design — that's
# decoupled from the student's provider.
RSpec.describe "Tutor cross-provider integration", type: :integration do
  let(:student) { create(:student) }
  let(:subject_record) { create(:subject) }
  let(:question) { create(:question, part: create(:part, subject: subject_record), answer_type: "calcul") }
  let!(:answer) { create(:answer, question: question) }
  let(:conversation) do
    create(:conversation, student: student, subject: subject_record, lifecycle_state: "active")
  end

  shared_examples "tutor pipeline runs end-to-end" do |provider|
    it "executes ProcessMessage with provider=#{provider}" do
      stub_const("ENV", ENV.to_hash.merge("ANTHROPIC_API_KEY" => "test-key"))
      student.update!(api_provider: provider, api_key: "fake-key")

      allow(Tutor::CallLlm).to receive(:call).and_return(
        Tutor::Result.ok(full_content: "Tutor response.")
      )
      allow(Tutor::Classify).to receive(:call).and_return(
        Tutor::Result.ok(annotation: { "gives_formula" => false, "concepts" => [] })
      )
      allow(Tutor::BroadcastDone).to receive(:call).and_return(Tutor::Result.ok)

      result = Tutor::ProcessMessage.call(
        conversation:  conversation,
        student_input: "Bonjour",
        question:      question,
        access_code:   "tutor-sim"
      )

      expect(result.ok?).to be(true)
    end
  end

  it_behaves_like "tutor pipeline runs end-to-end", "anthropic"
  it_behaves_like "tutor pipeline runs end-to-end", "openrouter"
  it_behaves_like "tutor pipeline runs end-to-end", "openai"
  it_behaves_like "tutor pipeline runs end-to-end", "google"
end
```

- [ ] **Step 2: Run, expect green**

Run: `bundle exec rspec spec/services/tutor/cross_provider_spec.rb`
Expected: 4 examples, 0 failures.

- [ ] **Step 3: Commit**

```bash
git add spec/services/tutor/cross_provider_spec.rb
git commit -m "test(tutor): cross-provider integration specs (4 providers)

Verifies ProcessMessage flow runs end-to-end for anthropic / openrouter /
openai / google providers with stubbed CallLlm + Classify + BroadcastDone.
Confirms no hard dependency on Anthropic in the main tutor path."
```

---

### Task 20: Rewrite `tutor_simulation/structural_metrics.rb`

**Files:**
- Modify: `app/services/tutor_simulation/structural_metrics.rb`
- Modify: `spec/services/tutor_simulation/structural_metrics_spec.rb` (if exists; else create)

- [ ] **Step 1: Write the failing spec**

Create or replace `spec/services/tutor_simulation/structural_metrics_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe TutorSimulation::StructuralMetrics do
  let(:student) { create(:student) }
  let(:subject_record) { create(:subject) }
  let(:question) { create(:question, part: create(:part, subject: subject_record), answer_type: "calcul") }
  let(:conversation) { create(:conversation, student: student, subject: subject_record) }

  def append(type, **payload)
    Tutor::RecordEvent.call(conversation: conversation, question_id: question.id,
                            type: type, source: "code", **payload)
    conversation.reload
  end

  describe "resolution_rate" do
    it "is 1.0 when student_attempt verdict=correct precedes viewed_correction" do
      append("student_attempt", verdict: "correct", content: "56,73")

      metrics = described_class.compute(conversation: conversation, question_ids: [question.id])
      expect(metrics[:resolution_rate]).to eq(1.0)
    end

    it "is 0.0 when student_attempt correct comes after viewed_correction" do
      append("viewed_correction")
      append("student_attempt", verdict: "correct", content: "56,73")

      metrics = described_class.compute(conversation: conversation, question_ids: [question.id])
      expect(metrics[:resolution_rate]).to eq(0.0)
    end

    it "is 0.0 when no correct attempt exists" do
      append("student_attempt", verdict: "incorrect", content: "5673")
      metrics = described_class.compute(conversation: conversation, question_ids: [question.id])
      expect(metrics[:resolution_rate]).to eq(0.0)
    end
  end

  describe "cap_violations" do
    it "counts cap_violation events" do
      append("cap_violation")
      append("cap_violation")
      metrics = described_class.compute(conversation: conversation, question_ids: [question.id])
      expect(metrics[:cap_violations]).to eq(2)
    end
  end

  describe "proactive_help_rate" do
    it "is 0 when all tutor_gave events follow a chip_click student_attempt" do
      # Simulated: an attempt then a tutor_gave (not proactive)
      append("student_attempt", verdict: "incorrect")
      append("tutor_gave", what: "formule")
      metrics = described_class.compute(conversation: conversation, question_ids: [question.id])
      expect(metrics[:proactive_help_rate]).to eq(0.0)
    end

    it "is 1.0 when tutor_gave appears with no preceding student_attempt" do
      append("tutor_gave", what: "formule")
      metrics = described_class.compute(conversation: conversation, question_ids: [question.id])
      expect(metrics[:proactive_help_rate]).to eq(1.0)
    end
  end

  describe "mean_help_steps_before_resolution" do
    it "averages tutor_gave count up to first correct attempt" do
      append("tutor_gave", what: "formule")
      append("tutor_gave", what: "valeur")
      append("student_attempt", verdict: "correct")
      metrics = described_class.compute(conversation: conversation, question_ids: [question.id])
      expect(metrics[:mean_help_steps_before_resolution]).to eq(2.0)
    end
  end

  describe "correct_attempts_after_help_rate" do
    it "is 1.0 when correct attempt follows a tutor_gave" do
      append("tutor_gave", what: "formule")
      append("student_attempt", verdict: "correct")
      metrics = described_class.compute(conversation: conversation, question_ids: [question.id])
      expect(metrics[:correct_attempts_after_help_rate]).to eq(1.0)
    end
  end
end
```

- [ ] **Step 2: Run to verify failure**

Run: `bundle exec rspec spec/services/tutor_simulation/structural_metrics_spec.rb`
Expected: FAIL.

- [ ] **Step 3: Replace `app/services/tutor_simulation/structural_metrics.rb`**

```ruby
module TutorSimulation
  # 062: structural metrics computed from QuestionTrace events.
  # No phase-rank, no spotting concepts. Aligned with redesign goals:
  # - resolution_rate (main metric)
  # - cap_violations (target = 0)
  # - mean_help_steps_before_resolution
  # - proactive_help_rate
  # - correct_attempts_after_help_rate
  # - attempts_per_question
  # - correction_view_rate
  # - mean_turns_to_resolution
  class StructuralMetrics
    def self.compute(conversation:, question_ids:)
      new(conversation: conversation, question_ids: question_ids).compute
    end

    def initialize(conversation:, question_ids:)
      @conversation = conversation
      @question_ids = Array(question_ids).map(&:to_i)
    end

    def compute
      traces = @question_ids.map { |qid| @conversation.tutor_state.trace_for(qid) }

      {
        resolution_rate:                   resolution_rate(traces),
        cap_violations:                    cap_violations(traces),
        mean_help_steps_before_resolution: mean_help_steps_before_resolution(traces),
        proactive_help_rate:               proactive_help_rate(traces),
        correct_attempts_after_help_rate:  correct_attempts_after_help_rate(traces),
        attempts_per_question:             attempts_per_question(traces),
        correction_view_rate:              correction_view_rate(traces),
        mean_turns_to_resolution:          mean_turns_to_resolution(traces)
      }
    end

    private

    def resolution_rate(traces)
      return 0.0 if traces.empty?
      resolved = traces.count { |t| resolved_without_correction?(t) }
      (resolved.to_f / traces.size).round(3)
    end

    def resolved_without_correction?(trace)
      first_correct = trace.events.index { |e| e["type"] == "student_attempt" && e["verdict"] == "correct" }
      first_view    = trace.events.index { |e| e["type"] == "viewed_correction" }
      return false unless first_correct
      first_view.nil? || first_correct < first_view
    end

    def cap_violations(traces)
      traces.sum { |t| t.events.count { |e| e["type"] == "cap_violation" } }
    end

    def mean_help_steps_before_resolution(traces)
      counts = traces.filter_map do |t|
        idx = t.events.index { |e| e["type"] == "student_attempt" && e["verdict"] == "correct" }
        next nil if idx.nil?
        t.events[0...idx].count { |e| e["type"] == "tutor_gave" }
      end
      return 0.0 if counts.empty?
      (counts.sum.to_f / counts.size).round(3)
    end

    def proactive_help_rate(traces)
      tutor_gaves   = traces.flat_map { |t| t.events.each_with_index.select { |(e, _)| e["type"] == "tutor_gave" } }
      return 0.0 if tutor_gaves.empty?

      proactive = traces.flat_map do |t|
        t.events.each_with_index.select do |(e, i)|
          e["type"] == "tutor_gave" && t.events[0...i].none? { |prev| prev["type"] == "student_attempt" }
        end
      end

      total_gives = traces.sum { |t| t.events.count { |e| e["type"] == "tutor_gave" } }
      return 0.0 if total_gives.zero?
      (proactive.size.to_f / total_gives).round(3)
    end

    def correct_attempts_after_help_rate(traces)
      correct_attempts = traces.sum { |t| t.events.count { |e| e["type"] == "student_attempt" && e["verdict"] == "correct" } }
      return 0.0 if correct_attempts.zero?

      after_help = traces.sum do |t|
        t.events.each_with_index.count do |e, i|
          e["type"] == "student_attempt" && e["verdict"] == "correct" &&
            t.events[0...i].any? { |prev| prev["type"] == "tutor_gave" }
        end
      end
      (after_help.to_f / correct_attempts).round(3)
    end

    def attempts_per_question(traces)
      return 0.0 if traces.empty?
      total = traces.sum { |t| t.events.count { |e| e["type"] == "student_attempt" } }
      (total.to_f / traces.size).round(3)
    end

    def correction_view_rate(traces)
      return 0.0 if traces.empty?
      viewed = traces.count { |t| t.events.any? { |e| e["type"] == "viewed_correction" } }
      (viewed.to_f / traces.size).round(3)
    end

    def mean_turns_to_resolution(traces)
      turns = traces.filter_map do |t|
        idx = t.events.index { |e| e["type"] == "student_attempt" && e["verdict"] == "correct" }
        next nil if idx.nil?
        # turn count = number of student_attempt events up to and including the correct one
        t.events[0..idx].count { |e| e["type"] == "student_attempt" }
      end
      return 0.0 if turns.empty?
      (turns.sum.to_f / turns.size).round(3)
    end
  end
end
```

- [ ] **Step 4: Run to verify pass**

Run: `bundle exec rspec spec/services/tutor_simulation/structural_metrics_spec.rb`
Expected: 6 examples, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add app/services/tutor_simulation/structural_metrics.rb \
        spec/services/tutor_simulation/structural_metrics_spec.rb
git commit -m "refactor(sim): rewrite StructuralMetrics for 062 trace-based metrics

resolution_rate (main), cap_violations (target 0),
mean_help_steps_before_resolution, proactive_help_rate,
correct_attempts_after_help_rate, attempts_per_question,
correction_view_rate, mean_turns_to_resolution.

049 phase-based metrics (PHASE_RANK, STATE_TARGETS,
dt_dr_leak_count_non_spotting) removed."
```

---

### Task 21: Update sim runner and student_simulator for 062 (collaborative profile only)

**Files:**
- Modify: `app/services/tutor_simulation/runner.rb`
- Modify: `app/services/tutor_simulation/student_simulator.rb`
- Modify: `lib/tasks/tutor_simulate.rake`

- [ ] **Step 1: Update Runner to compute new metrics**

In `runner.rb`, locate where `StructuralMetrics.compute` is called. Update the call site to pass `question_ids:` (the list of questions seen during the simulation) instead of `phase_per_turn`. Remove any `phase_per_turn` tracking.

Example change in `runner.rb` (likely around `simulate_question`):

Replace any line like:

```ruby
StructuralMetrics.compute(conversation: conversation, phase_per_turn: phase_per_turn)
```

with:

```ruby
StructuralMetrics.compute(conversation: conversation, question_ids: [question.id])
```

And drop the `phase_per_turn = [...]` tracking lines (lines 100, 121, 128 from the previous read).

- [ ] **Step 2: Restrict profiles to `collaboratif` only for 062**

In `student_simulator.rb` (the file that defines profile prompts), keep only the `collaboratif` profile. Profiles `autonome` and `passif` are deferred to PR 063 — leave them defined but mark them with a comment "// 063 follow-up", or remove them entirely until 063.

If the file uses a `PROFILES` constant (or similar), trim it to:

```ruby
PROFILES = {
  collaboratif: {
    name: "élève collaboratif",
    description: "tente d'abord, demande aide graduellement (formule → valeur → calcul), " \
                 "demande la correction si bloqué 8+ tours."
  }
  # autonome and passif: PR 063
}.freeze
```

The simulator must be wired to actually click chips (representing chip clicks via the message channel — same flow as a real student typing the chip's payload string). Since chips are buttons whose payload is a free-text message, the simulator can keep producing free-text via its prompt, biased toward chip-style payloads ("Quelle formule je dois utiliser ?", "Donne-moi un indice…").

- [ ] **Step 3: Update the rake task**

In `lib/tasks/tutor_simulate.rake`, in the section that prints metrics, output the new metric keys instead of the old ones. Replace the print block by:

```ruby
puts "  resolution_rate:                  #{metrics[:resolution_rate]}"
puts "  cap_violations:                   #{metrics[:cap_violations]}"
puts "  mean_help_steps_before_resolution: #{metrics[:mean_help_steps_before_resolution]}"
puts "  proactive_help_rate:              #{metrics[:proactive_help_rate]}"
puts "  correct_attempts_after_help_rate: #{metrics[:correct_attempts_after_help_rate]}"
puts "  attempts_per_question:            #{metrics[:attempts_per_question]}"
puts "  correction_view_rate:             #{metrics[:correction_view_rate]}"
puts "  mean_turns_to_resolution:         #{metrics[:mean_turns_to_resolution]}"
```

Also update the `desc` block at the top to reflect the new env var defaults (PROFILES default to `collaboratif`).

- [ ] **Step 4: Smoke-run the sim locally (optional, no LLM call needed)**

Run: `bundle exec rake tutor:simulate[1] PROFILES=collaboratif TURNS=2 QUESTIONS=1.1`
(Use a real subject id from your dev DB.)
Expected: command runs to completion and prints the new metric keys.

- [ ] **Step 5: Commit**

```bash
git add app/services/tutor_simulation/runner.rb \
        app/services/tutor_simulation/student_simulator.rb \
        lib/tasks/tutor_simulate.rake
git commit -m "refactor(sim): wire 062 metrics in Runner and rake task

Removes phase_per_turn tracking — passes question_ids to StructuralMetrics.
Profiles trimmed to 'collaboratif' only (autonome/passif deferred to 063).
Rake task prints the new metric set."
```

---

### Task 22: Update tutor simulation workflow CI

**Files:**
- Modify: `.github/workflows/tutor_simulation.yml`

- [ ] **Step 1: Update SC thresholds in the workflow**

Find the step that asserts metrics in the workflow (likely a `run:` shell step that parses the JSON output). Update it to assert:

- `resolution_rate >= 0.70`
- `cap_violations == 0`

Drop assertions on phase-based metrics.

Example replacement:

```yaml
- name: Assert SC-A and SC-B
  run: |
    if [ -f "tmp/tutor_simulations/latest/metrics.json" ]; then
      RR=$(jq -r '.resolution_rate' tmp/tutor_simulations/latest/metrics.json)
      CV=$(jq -r '.cap_violations'  tmp/tutor_simulations/latest/metrics.json)
      echo "resolution_rate=$RR cap_violations=$CV"
      python3 -c "import sys; sys.exit(0 if float('$RR') >= 0.70 else 1)" || (echo "SC-A failed" && exit 1)
      [ "$CV" = "0" ] || (echo "SC-B failed: $CV violations" && exit 1)
    fi
```

(Adjust shell semantics to the actual workflow language already used.)

- [ ] **Step 2: Commit**

```bash
git add .github/workflows/tutor_simulation.yml
git commit -m "ci(tutor): update simulation workflow thresholds for 062 SC-A and SC-B

resolution_rate >= 0.70 (SC-A); cap_violations == 0 (SC-B).
049 phase-based assertions removed."
```

---

## Phase 6 — Final pass

### Task 23: Update remaining feature specs to 062 expectations

**Files (modify):**
- `spec/features/student_tutor_full_flow_spec.rb`
- `spec/features/student_tutor_chat_spec.rb`
- `spec/features/student_tutor_activation_spec.rb`
- `spec/features/student_tutor_chips_spec.rb`
- `spec/jobs/process_tutor_message_job_spec.rb`
- `spec/support/tutor_feature_helpers.rb` (if asserting on phases)

- [ ] **Step 1: For each feature spec, scan and adapt**

For each file, run:

```bash
grep -nE "current_phase|spotting_type|spotting_data|guiding|validating|feedback|welcome_sent|hints_used|intro_seen|mark_intro_seen|confidence" spec/features/student_tutor_*.rb
```

For each match:
- If the assertion is on a 049 phase or removed flag, **delete the line or scenario** (do not turn into pending).
- If the assertion is on a behavior still valid in 062 (drawer opens, message arrives, chip clicks), keep it; update DOM selectors if the chip class names changed (Task 9 step 4).

Drop scenarios that test:
- spotting phase content (`spec/features/student_tutor_spotting_spec.rb` already deleted in Task 18)
- confidence form interactions
- intro_seen marking
- welcome_sent / re-greeting after 12h

- [ ] **Step 2: Run each feature spec individually, fix until green**

```bash
bundle exec rspec spec/features/student_tutor_chat_spec.rb
bundle exec rspec spec/features/student_tutor_full_flow_spec.rb
bundle exec rspec spec/features/student_tutor_activation_spec.rb
bundle exec rspec spec/features/student_tutor_chips_spec.rb
```

- [ ] **Step 3: Run the job spec**

```bash
bundle exec rspec spec/jobs/process_tutor_message_job_spec.rb
```

Adapt to use the new ProcessMessage flow (no phase assertions).

- [ ] **Step 4: Commit**

```bash
git add spec/features/student_tutor_*.rb spec/jobs/process_tutor_message_job_spec.rb \
        spec/support/tutor_feature_helpers.rb
git commit -m "test(tutor): align legacy feature/job specs to 062 expectations

Drops phase-based assertions, intro_seen / mark_intro_seen scenarios,
confidence form interactions, welcome_sent / re-greeting checks.
Keeps drawer-open / message-arrives / chip-click coverage."
```

---

### Task 24: Run full suite and lint, push, open PR

- [ ] **Step 1: Full suite green**

Run: `bundle exec rspec`
Expected: 0 failures, 0 pending.

If any failure, diagnose and fix.

- [ ] **Step 2: Rubocop clean**

Run: `bundle exec rubocop`
Expected: clean. Apply autocorrect if minor; fix manually if not.

- [ ] **Step 3: ERB lint (if used in project)**

Run: `bundle exec erb_lint --lint-all` (or whatever the project uses)
Expected: clean.

- [ ] **Step 4: Push to origin**

```bash
git push -u origin 062-tutor-redesign-from-scratch
```

- [ ] **Step 5: Open the PR**

```bash
gh pr create --title "feat(tutor): redesign from scratch — bouton SOS, trace-based, calibrated chips (062)" --body "$(cat <<'EOF'
## Summary

- Remplace la machine d'état 9 phases pilotée par le LLM (049) par une architecture où le code Ruby pilote la trace, les chips et la phase dérivée.
- Approche F retenue : 1 appel LLM par tour (chemin critique) + classifier inline post-response sur clé serveur Anthropic.
- Mapping chips calibré sur corpus BAC STI2D 2025 (~90 questions, 7 answer_types × 5 phases).
- Reset complet du `tutor_state` ; AASM passe de 5 à 3 états.
- Nouveau prompt en 6 blocs (POSTURE / CONTEXTE / CORRECTION / BUDGET / CAP / ACTION) avec cap résultat formulé en positif (OU).

Voir le design : `docs/superpowers/specs/2026-05-06-tutor-redesign-from-scratch-design.md`
Mapping chips : `docs/superpowers/specs/2026-05-06-tutor-redesign-chips-mapping.md`
Plan d'implémentation : `docs/superpowers/plans/2026-05-06-tutor-redesign-from-scratch.md`

## Test plan

- [x] Specs unitaires (Tutor::DerivePhase, RecordEvent, ChipsPresenter, BehaviorHints, Classify, BroadcastDone, BuildContext, ProcessMessage)
- [x] Spec roundtrip TutorStateType
- [x] Spec AASM 3 états
- [x] Specs requests Student::Events / Student::Conversations
- [x] Specs features student_tutor_navigation / events_page / cap_results
- [x] Spec cross-provider (anthropic / openrouter / openai / google)
- [x] Spec StructuralMetrics avec nouvelles métriques
- [ ] CI verte (specs unitaires + request + feature)
- [ ] Sim sur branche : `resolution_rate >= 0.70`
- [ ] Sim sur branche : `cap_violations == 0`
- [ ] Pas de pending/xscenario

## Notes

- Merge **normal** (pas squash). Override de `feedback_squash_large_refactors` — décision a2p0.
- Profils élèves `autonome` et `passif` + juge LLM réécrit : **PR 063** (suivi).
- Calibrage chips livré en session parallèle, persisté dans `docs/superpowers/specs/2026-05-06-tutor-redesign-chips-mapping.md`.
EOF
)"
```

Return the PR URL.

- [ ] **Step 6: Trigger the simulation workflow**

```bash
gh workflow run tutor_simulation.yml -f subject_id=<a real subject id> -f turns=8 -f profiles=collaboratif
```

Wait for completion, verify SC-A and SC-B are met.

- [ ] **Step 7: Spec self-review on the design doc**

Re-read `docs/superpowers/specs/2026-05-06-tutor-redesign-from-scratch-design.md` and check that the implementation matches it. If you find a divergence, either:
- Fix the implementation (preferred), or
- Update the spec in a single `docs(spec)` commit on this branch with explanation in the message (cf. memory `feedback_spec_drift`).

- [ ] **Step 8: Final commit (if any spec drift)**

```bash
git add docs/superpowers/specs/2026-05-06-tutor-redesign-from-scratch-design.md
git commit -m "docs(spec): align 062 design doc with implementation

<explain the divergence and reason>"
git push
```

---

## Validation gates summary

| Gate | When | Pass criterion |
|---|---|---|
| Unit specs green per task | After every Task 2-23 | `0 failures` for the touched spec files |
| Cross-provider spec | After Task 19 | 4 examples green |
| Full suite green | After Task 24 step 1 | `0 failures, 0 pending` |
| Rubocop clean | Task 24 step 2 | exit 0 |
| Sim on branch | Task 24 step 6 | `resolution_rate ≥ 0.70` AND `cap_violations == 0` |
| Spec self-review | Task 24 step 7 | no divergence (or doc patched) |

---

## Estimation indicative

| Phase | Tasks | Cumulative effort |
|---|---|---|
| 1. Data foundation | 1, 2, 3 | ~3-4 h |
| 2. Pure services | 4, 5, 6, 7, 8, 9 | ~6-8 h |
| 3. Prompt + orchestration | 10, 11 | ~3-4 h |
| 4. AASM + controllers + drawer | 12, 13, 14, 15, 16, 17 | ~5-7 h |
| 5. Cleanup + sim | 18, 19, 20, 21, 22 | ~3-4 h |
| 6. Final | 23, 24 | ~2-3 h |
| **Total** | 24 tasks | **~22-30 h** |

---

## Self-Review checklist (run inline)

**Spec coverage:**
- US1 Aide graduée → Tasks 6 (chips), 10 (prompt), 11 (orchestrator), 17 (cap feature)
- US2 Events page → Tasks 13 (controller/route), 16 (page buttons)
- US3 Cap résultat → Tasks 6 (chips disabled), 10 (prompt cap block), 17 (feature)
- US4 Navigation → Tasks 15 (drawer + Stimulus), navigation feature spec
- US5 Greeting unique → Task 11 (mark_greeted_if_needed), 10 (prompt fresh_open)
- US6 answer_types adaptatifs → Tasks 6 (mapping), 7 (BehaviorHints)
- 3 invariants → Tasks 2 (no :phase member), 5 (append-only), 11+20 (cap violation tracking)
- Migration depuis 049 → Tasks 1, 12, 18

**No placeholders:** all code blocks present; chip mapping is the literal calibrated content; prompt blocks are literal strings, not `// TODO`.

**Type consistency:** `QuestionTrace` exposes `events`, `budget`, `cap_active?`, `append`, `last_signal`. `TutorState` exposes `current_question_id`, `greeted`, `question_traces`, `concepts_seen`, `trace_for`, `with_trace`, `with_concept`. Used consistently across Tasks 2, 5, 6, 7, 10, 11, 20.
