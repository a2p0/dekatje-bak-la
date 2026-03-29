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

    it "accepts an optional model parameter" do
      client = described_class.build(provider: :anthropic, api_key: "sk-test", model: "claude-haiku-4-5-20251001")
      expect(client).to respond_to(:call)
    end

    it "calls anthropic API with correct headers" do
      stub = stub_request(:post, "https://api.anthropic.com/v1/messages")
        .with(headers: { "x-api-key" => "sk-ant-test" })
        .to_return(
          status: 200,
          body: { content: [{ text: '{"parts":[]}' }] }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      client = described_class.build(provider: :anthropic, api_key: "sk-ant-test")
      result = client.call(
        messages: [{ role: "user", content: "test" }],
        system: "system prompt",
        max_tokens: 100,
        temperature: 0.1
      )

      expect(stub).to have_been_requested
      expect(result).to include("parts")
    end

    it "uses custom model in anthropic request body" do
      stub = stub_request(:post, "https://api.anthropic.com/v1/messages")
        .with(body: hash_including("model" => "claude-haiku-4-5-20251001"))
        .to_return(
          status: 200,
          body: { content: [{ text: "hello" }] }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      client = described_class.build(provider: :anthropic, api_key: "sk-test", model: "claude-haiku-4-5-20251001")
      client.call(messages: [{ role: "user", content: "test" }], system: "sys", max_tokens: 100)

      expect(stub).to have_been_requested
    end

    it "uses custom model in google endpoint path" do
      stub = stub_request(:post, "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-pro-preview-06-05:generateContent")
        .to_return(
          status: 200,
          body: { candidates: [{ content: { parts: [{ text: "hello" }] } }] }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      client = described_class.build(provider: :google, api_key: "gk-test", model: "gemini-2.5-pro-preview-06-05")
      client.call(messages: [{ role: "user", content: "test" }], system: "sys", max_tokens: 100)

      expect(stub).to have_been_requested
    end

    it "uses default model when none specified" do
      stub = stub_request(:post, "https://api.anthropic.com/v1/messages")
        .with(body: hash_including("model" => "claude-sonnet-4-5-20251001"))
        .to_return(
          status: 200,
          body: { content: [{ text: "hello" }] }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      client = described_class.build(provider: :anthropic, api_key: "sk-test")
      client.call(messages: [{ role: "user", content: "test" }], system: "sys", max_tokens: 100)

      expect(stub).to have_been_requested
    end
  end
end
