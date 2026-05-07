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
