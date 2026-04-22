require "rails_helper"

RSpec.describe Tutor::ParseToolCalls do
  describe ".call" do
    context "with an empty array" do
      it "returns ok with empty parsed array" do
        result = described_class.call(tool_calls: [])
        expect(result.ok?).to be true
        expect(result.value[:parsed]).to eq([])
      end
    end

    context "with a ruby_llm tool call object responding to name and arguments" do
      let(:tool_call) do
        double("RubyLLM::ToolCall",
          name:      "transition",
          arguments: { "phase" => "guiding", "question_id" => 5 }
        )
      end

      it "normalizes to {name:, args:} hash" do
        result = described_class.call(tool_calls: [ tool_call ])
        expect(result.ok?).to be true
        parsed = result.value[:parsed]
        expect(parsed.length).to eq(1)
        expect(parsed.first[:name]).to eq("transition")
        expect(parsed.first[:args]).to eq({ "phase" => "guiding", "question_id" => 5 })
      end
    end

    context "when tool_calls already came from CallLlm as a flat array (post-adapter)" do
      let(:tc_a) { double("TC", name: "transition", arguments: { "phase" => "greeting" }) }
      let(:tc_b) { double("TC", name: "request_hint", arguments: { "level" => 1 }) }

      it "normalizes each entry" do
        result = described_class.call(tool_calls: [ tc_a, tc_b ])
        expect(result.value[:parsed].length).to eq(2)
        expect(result.value[:parsed].first[:name]).to eq("transition")
      end
    end

    context "with multiple tool calls" do
      let(:tc1) { double("TC1", name: "transition", arguments: { "phase" => "guiding" }) }
      let(:tc2) { double("TC2", name: "update_learner_model", arguments: { "concept_mastered" => "énergie" }) }

      it "normalizes all of them" do
        result = described_class.call(tool_calls: [ tc1, tc2 ])
        expect(result.value[:parsed].map { |t| t[:name] }).to eq(%w[transition update_learner_model])
      end
    end
  end
end