require "rails_helper"

RSpec.describe Tutor::Tools::UpdateLearnerModelTool do
  it "inherits from RubyLLM::Tool" do
    expect(described_class.ancestors).to include(RubyLLM::Tool)
  end

  it "exposes a stable short name to the LLM" do
    expect(described_class.new.name).to eq("update_learner_model")
  end

  describe "#execute" do
    it "returns ack with an empty call" do
      result = described_class.new.execute
      expect(result[:ok]).to be true
      expect(result[:recorded]).to eq(
        concept_mastered:     nil,
        concept_to_revise:    nil,
        discouragement_delta: nil
      )
    end

    it "returns ack with filled args" do
      result = described_class.new.execute(
        concept_mastered:     "énergie primaire",
        concept_to_revise:    "rendement",
        discouragement_delta: 1
      )
      expect(result[:recorded][:concept_mastered]).to eq("énergie primaire")
      expect(result[:recorded][:concept_to_revise]).to eq("rendement")
      expect(result[:recorded][:discouragement_delta]).to eq(1)
    end
  end
end