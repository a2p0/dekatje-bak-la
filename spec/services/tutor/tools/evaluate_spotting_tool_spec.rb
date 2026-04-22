require "rails_helper"

RSpec.describe Tutor::Tools::EvaluateSpottingTool do
  it "inherits from RubyLLM::Tool" do
    expect(described_class.ancestors).to include(RubyLLM::Tool)
  end

  it "exposes a stable short name to the LLM" do
    expect(described_class.new.name).to eq("evaluate_spotting")
  end

  describe "#execute" do
    it "returns ack with recorded outcome" do
      result = described_class.new.execute(outcome: "success")
      expect(result).to eq(ok: true, recorded: { outcome: "success" })
    end
  end
end