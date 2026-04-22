require "rails_helper"

RSpec.describe Tutor::Tools::RequestHintTool do
  it "inherits from RubyLLM::Tool" do
    expect(described_class.ancestors).to include(RubyLLM::Tool)
  end

  it "exposes a stable short name to the LLM" do
    expect(described_class.new.name).to eq("request_hint")
  end

  describe "#execute" do
    it "returns ack with recorded level" do
      result = described_class.new.execute(level: 2)
      expect(result).to eq(ok: true, recorded: { level: 2 })
    end
  end
end