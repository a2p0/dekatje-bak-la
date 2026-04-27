require "rails_helper"

RSpec.describe TutorState do
  describe ".default" do
    subject(:state) { described_class.default }

    it "returns a TutorState instance" do
      expect(state).to be_a(TutorState)
    end

    it "has current_phase = 'idle'" do
      expect(state.current_phase).to eq("idle")
    end

    it "has nil current_question_id" do
      expect(state.current_question_id).to be_nil
    end

    it "has empty concepts_mastered array" do
      expect(state.concepts_mastered).to eq([])
    end

    it "has empty concepts_to_revise array" do
      expect(state.concepts_to_revise).to eq([])
    end

    it "has discouragement_level = 0" do
      expect(state.discouragement_level).to eq(0)
    end

    it "has empty question_states hash" do
      expect(state.question_states).to eq({})
    end
  end

  describe "immutability" do
    it "is frozen (Data classes are value objects)" do
      expect(described_class.default).to be_frozen
    end

    it "raises when trying to modify question_states in place" do
      state = described_class.default
      expect { state.question_states["42"] = {} }.to raise_error(FrozenError)
    end
  end

  describe "#to_prompt" do
    it "includes phase and discouragement" do
      state = TutorState.new(
        current_phase:         "reading",
        current_question_id:   nil,
        concepts_mastered:     [],
        concepts_to_revise:    [],
        discouragement_level:  0,
        question_states:       {}, welcome_sent: false, last_activity_at: nil)
      prompt = state.to_prompt
      expect(prompt).to include("Phase courante : reading.")
      expect(prompt).to include("Niveau de découragement : 0/3.")
    end

    it "includes question context when current_question_id is set" do
      qs = QuestionState.new(
        phase: "enonce", step: "initial", hints_used: 2, last_confidence: 3,
        error_types: [], completed_at: nil, intro_seen: false)
      state = TutorState.new(
        current_phase:         "guiding",
        current_question_id:   42,
        concepts_mastered:     [ "énergie primaire" ],
        concepts_to_revise:    [ "rendement" ],
        discouragement_level:  1,
        question_states:       { "42" => qs }, welcome_sent: false, last_activity_at: nil)
      prompt = state.to_prompt
      expect(prompt).to include("L'élève travaille sur la question 42.")
      expect(prompt).to include("Concepts maîtrisés : énergie primaire.")
      expect(prompt).to include("Points à revoir : rendement.")
      expect(prompt).to include("Indices utilisés sur cette question : 2/5.")
      expect(prompt).to include("Dernière confiance déclarée : 3/5.")
    end
  end
end

RSpec.describe QuestionState do
  describe "construction" do
    subject(:qs) do
      QuestionState.new(
        phase: "enonce",
        step: 1,
        hints_used: 2,
        last_confidence: 4,
        error_types: [ "calcul" ],
        completed_at: nil, intro_seen: false)
    end

    it "stores step" do
      expect(qs.step).to eq(1)
    end

    it "stores hints_used" do
      expect(qs.hints_used).to eq(2)
    end

    it "stores last_confidence" do
      expect(qs.last_confidence).to eq(4)
    end

    it "stores error_types" do
      expect(qs.error_types).to eq([ "calcul" ])
    end
  end

  describe "intro_seen (044)" do
    it "defaults to false" do
      qs = QuestionState.new(phase: "enonce", step: nil, hints_used: 0, last_confidence: nil,
                             error_types: [], completed_at: nil, intro_seen: false)
      expect(qs.intro_seen).to eq(false)
    end

    it "can be set to true" do
      qs = QuestionState.new(phase: "enonce", step: nil, hints_used: 0, last_confidence: nil,
                             error_types: [], completed_at: nil, intro_seen: true)
      expect(qs.intro_seen).to eq(true)
    end
  end
end

RSpec.describe TutorState, "(049 — last_activity_at)" do
  describe "last_activity_at field" do
    it "defaults to nil on TutorState.default" do
      expect(described_class.default.last_activity_at).to be_nil
    end

    it "can be set to an ISO8601 string via .with" do
      ts = Time.current.iso8601
      state = described_class.default.with(last_activity_at: ts)
      expect(state.last_activity_at).to eq(ts)
    end
  end

  describe "TutorStateType retro-compatibility for last_activity_at" do
    let(:type) { TutorStateType.new }

    it "reads last_activity_at as nil when key absent from stored JSONB" do
      old_hash = {
        "current_phase" => "idle",
        "current_question_id" => nil,
        "concepts_mastered" => [],
        "concepts_to_revise" => [],
        "discouragement_level" => 0,
        "question_states" => {},
        "welcome_sent" => false
      }
      state = type.cast(old_hash)
      expect(state.last_activity_at).to be_nil
    end

    it "round-trips last_activity_at through serialize/cast" do
      ts = "2026-04-25T10:00:00Z"
      original = described_class.default.with(last_activity_at: ts)
      serialized = type.serialize(original)
      parsed = JSON.parse(serialized)
      restored = type.cast(parsed)
      expect(restored.last_activity_at).to eq(ts)
    end
  end
end

RSpec.describe QuestionState, "(049 — phase)" do
  describe "phase field" do
    it "can be set to a phase string" do
      qs = QuestionState.new(
        phase: "guiding", step: nil, hints_used: 0,
        last_confidence: nil, error_types: [], completed_at: nil, intro_seen: false
      )
      expect(qs.phase).to eq("guiding")
    end
  end

  describe "TutorStateType retro-compatibility for QuestionState#phase" do
    let(:type) { TutorStateType.new }

    it "reads phase as 'enonce' when key absent from stored question_state" do
      old_hash = {
        "current_phase" => "guiding",
        "current_question_id" => 42,
        "concepts_mastered" => [],
        "concepts_to_revise" => [],
        "discouragement_level" => 0,
        "question_states" => {
          "42" => {
            "step" => "initial",
            "hints_used" => 0,
            "last_confidence" => nil,
            "error_types" => [],
            "completed_at" => nil,
            "intro_seen" => false
          }
        },
        "welcome_sent" => false
      }
      state = type.cast(old_hash)
      expect(state.question_states["42"].phase).to eq("enonce")
    end

    it "reads phase as invalid-phase fallback 'enonce' for unknown phase string" do
      hash = {
        "current_phase" => "guiding",
        "current_question_id" => 42,
        "concepts_mastered" => [],
        "concepts_to_revise" => [],
        "discouragement_level" => 0,
        "question_states" => {
          "42" => {
            "phase" => "reading",
            "step" => nil, "hints_used" => 0,
            "last_confidence" => nil,
            "error_types" => [], "completed_at" => nil, "intro_seen" => false
          }
        },
        "welcome_sent" => false,
        "last_activity_at" => nil
      }
      state = type.cast(hash)
      expect(state.question_states["42"].phase).to eq("enonce")
    end

    it "round-trips phase through serialize/cast" do
      qs = QuestionState.new(
        phase: "spotting_type", step: nil, hints_used: 0,
        last_confidence: nil, error_types: [], completed_at: nil, intro_seen: false
      )
      original = TutorState.default.with(question_states: { "7" => qs })
      serialized = type.serialize(original)
      parsed = JSON.parse(serialized)
      restored = type.cast(parsed)
      expect(restored.question_states["7"].phase).to eq("spotting_type")
    end
  end
end

RSpec.describe TutorState, "(044 — welcome_sent)" do
  describe "welcome_sent field" do
    it "defaults to false on TutorState.default" do
      expect(described_class.default.welcome_sent).to eq(false)
    end

    it "can be set to true via .with" do
      state = described_class.default.with(welcome_sent: true)
      expect(state.welcome_sent).to eq(true)
    end
  end

  describe "TutorStateType retro-compatibility" do
    let(:type) { TutorStateType.new }

    it "reads welcome_sent as false when key absent from stored JSONB" do
      old_hash = {
        "current_phase" => "idle",
        "current_question_id" => nil,
        "concepts_mastered" => [],
        "concepts_to_revise" => [],
        "discouragement_level" => 0,
        "question_states" => {}
      }
      state = type.cast(old_hash)
      expect(state.welcome_sent).to eq(false)
    end

    it "reads intro_seen as false when key absent from stored question_state" do
      old_hash = {
        "current_phase" => "idle",
        "current_question_id" => nil,
        "concepts_mastered" => [],
        "concepts_to_revise" => [],
        "discouragement_level" => 0,
        "question_states" => {
          "42" => {
            "step" => "initial",
            "hints_used" => 0,
            "last_confidence" => nil,
            "error_types" => [],
            "completed_at" => nil
          }
        }
      }
      state = type.cast(old_hash)
      expect(state.question_states["42"].intro_seen).to eq(false)
    end

    it "round-trips welcome_sent through serialize/cast" do
      original = described_class.default.with(welcome_sent: true)
      serialized = type.serialize(original)
      parsed = JSON.parse(serialized)
      restored = type.cast(parsed)
      expect(restored.welcome_sent).to eq(true)
    end

    it "round-trips intro_seen through serialize/cast" do
      qs = QuestionState.new(phase: "enonce", step: nil, hints_used: 0, last_confidence: nil,
                             error_types: [], completed_at: nil, intro_seen: true)
      original = described_class.default.with(question_states: { "7" => qs })
      serialized = type.serialize(original)
      parsed = JSON.parse(serialized)
      restored = type.cast(parsed)
      expect(restored.question_states["7"].intro_seen).to eq(true)
    end
  end
end
