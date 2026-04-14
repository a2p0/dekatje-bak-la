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
        question_states:       {}
      )
      prompt = state.to_prompt
      expect(prompt).to include("Phase courante : reading.")
      expect(prompt).to include("Niveau de découragement : 0/3.")
    end

    it "includes question context when current_question_id is set" do
      qs = QuestionState.new(
        step: "initial", hints_used: 2, last_confidence: 3,
        error_types: [], completed_at: nil
      )
      state = TutorState.new(
        current_phase:         "guiding",
        current_question_id:   42,
        concepts_mastered:     [ "énergie primaire" ],
        concepts_to_revise:    [ "rendement" ],
        discouragement_level:  1,
        question_states:       { "42" => qs }
      )
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
        step: 1,
        hints_used: 2,
        last_confidence: 4,
        error_types: [ "calcul" ],
        completed_at: nil
      )
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
end
