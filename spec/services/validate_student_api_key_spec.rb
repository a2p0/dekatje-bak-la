require "rails_helper"

RSpec.describe ValidateStudentApiKey do
  describe ".call" do
    it "returns true for working key" do
      fake_client = instance_double(AiClientFactory)
      allow(AiClientFactory).to receive(:build).and_return(fake_client)
      allow(fake_client).to receive(:call).and_return("OK")

      result = described_class.call(provider: "anthropic", api_key: "sk-test", model: "claude-haiku-4-5-20251001")
      expect(result).to be true
    end

    it "raises InvalidApiKeyError for bad key" do
      fake_client = instance_double(AiClientFactory)
      allow(AiClientFactory).to receive(:build).and_return(fake_client)
      allow(fake_client).to receive(:call).and_raise("API error 401: Unauthorized")

      expect {
        described_class.call(provider: "anthropic", api_key: "bad-key", model: "claude-haiku-4-5-20251001")
      }.to raise_error(ValidateStudentApiKey::InvalidApiKeyError, /401/)
    end

    it "raises InvalidApiKeyError for unknown provider" do
      expect {
        described_class.call(provider: "unknown", api_key: "sk-test", model: "some-model")
      }.to raise_error(ValidateStudentApiKey::InvalidApiKeyError, /Provider inconnu/)
    end

    it "raises InvalidApiKeyError on timeout" do
      fake_client = instance_double(AiClientFactory)
      allow(AiClientFactory).to receive(:build).and_return(fake_client)
      allow(fake_client).to receive(:call).and_raise(Faraday::TimeoutError)

      expect {
        described_class.call(provider: "openai", api_key: "sk-test", model: "gpt-4o-mini")
      }.to raise_error(ValidateStudentApiKey::InvalidApiKeyError, /Timeout/)
    end
  end
end
