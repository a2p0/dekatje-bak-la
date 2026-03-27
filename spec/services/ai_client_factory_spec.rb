require "rails_helper"

RSpec.describe AiClientFactory do
  describe ".build" do
    it "builds a client for anthropic provider" do
      client = described_class.build(provider: :anthropic, api_key: "sk-test")
      expect(client).to respond_to(:call)
    end

    it "builds a client for openrouter provider" do
      client = described_class.build(provider: :openrouter, api_key: "sk-test")
      expect(client).to respond_to(:call)
    end

    it "builds a client for openai provider" do
      client = described_class.build(provider: :openai, api_key: "sk-test")
      expect(client).to respond_to(:call)
    end

    it "builds a client for google provider" do
      client = described_class.build(provider: :google, api_key: "sk-test")
      expect(client).to respond_to(:call)
    end

    it "raises for unknown provider" do
      expect {
        described_class.build(provider: :unknown, api_key: "sk-test")
      }.to raise_error(AiClientFactory::UnknownProviderError)
    end

    it "calls anthropic API with correct headers" do
      stub = stub_request(:post, "https://api.anthropic.com/v1/messages")
        .with(headers: { "x-api-key" => "sk-ant-test" })
        .to_return(
          status: 200,
          body: { content: [ { text: '{"parts":[]}' } ] }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      client = described_class.build(provider: :anthropic, api_key: "sk-ant-test")
      result = client.call(
        messages: [ { role: "user", content: "test" } ],
        system: "system prompt",
        max_tokens: 100,
        temperature: 0.1
      )

      expect(stub).to have_been_requested
      expect(result).to include("parts")
    end
  end
end
