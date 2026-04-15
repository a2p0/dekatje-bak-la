require "rails_helper"

RSpec.describe Tutor::Tools::TransitionTool do
  it "inherits from RubyLLM::Tool" do
    expect(described_class.ancestors).to include(RubyLLM::Tool)
  end

  describe "#execute" do
    it "returns an ack with recorded phase only" do
      result = described_class.new.execute(phase: "greeting")
      expect(result).to eq(ok: true, recorded: { phase: "greeting", question_id: nil })
    end

    it "returns an ack with recorded phase and question_id" do
      result = described_class.new.execute(phase: "guiding", question_id: 42)
      expect(result).to eq(ok: true, recorded: { phase: "guiding", question_id: 42 })
    end
  end
end
