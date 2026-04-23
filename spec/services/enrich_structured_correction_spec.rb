require "rails_helper"

RSpec.describe EnrichStructuredCorrection do
  let(:answer) { create(:answer) }
  let(:api_key) { "sk-test" }
  let(:provider) { :anthropic }

  let(:valid_structured_correction) do
    {
      "input_data" => [
        { "name" => "Distance", "value" => "186 km", "source" => "mise_en_situation" }
      ],
      "final_answers" => [
        { "name" => "Consommation voiture", "value" => "56,73 l", "reasoning" => "30,5 × 186 / 100" }
      ],
      "intermediate_steps" => [ "Appliquer la formule Consommation × Distance / 100" ],
      "common_errors" => [
        { "error" => "Oublier de diviser par 100", "remediation" => "Vérifier la formule de base" }
      ]
    }
  end

  let(:fake_client) { instance_double("AiClient") }

  before do
    allow(AiClientFactory).to receive(:build).and_return(fake_client)
  end

  describe ".call" do
    context "when LLM returns valid JSON" do
      before do
        allow(fake_client).to receive(:call).and_return(valid_structured_correction.to_json)
      end

      it "returns a successful result" do
        result = described_class.call(answer: answer, api_key: api_key, provider: provider)
        expect(result.ok?).to be true
      end

      it "returns the parsed structured_correction hash" do
        result = described_class.call(answer: answer, api_key: api_key, provider: provider)
        expect(result.structured_correction).to include(
          "input_data", "final_answers", "intermediate_steps", "common_errors"
        )
      end

      it "builds the AI client with correct provider and api_key" do
        described_class.call(answer: answer, api_key: api_key, provider: provider)
        expect(AiClientFactory).to have_received(:build).with(
          provider: :anthropic, api_key: "sk-test"
        )
      end
    end

    context "when LLM returns malformed JSON" do
      before do
        allow(fake_client).to receive(:call).and_return("This is not JSON at all")
      end

      it "returns a failed result" do
        result = described_class.call(answer: answer, api_key: api_key, provider: provider)
        expect(result.ok?).to be false
      end

      it "includes an error message" do
        result = described_class.call(answer: answer, api_key: api_key, provider: provider)
        expect(result.error).to be_present
      end
    end

    context "when Faraday::TimeoutError is raised" do
      before do
        allow(fake_client).to receive(:call).and_raise(Faraday::TimeoutError, "timeout")
      end

      it "returns a failed result" do
        result = described_class.call(answer: answer, api_key: api_key, provider: provider)
        expect(result.ok?).to be false
      end

      it "includes the timeout error in the message" do
        result = described_class.call(answer: answer, api_key: api_key, provider: provider)
        expect(result.error).to be_present
      end

      it "does not raise an exception" do
        expect {
          described_class.call(answer: answer, api_key: api_key, provider: provider)
        }.not_to raise_error
      end
    end
  end
end
