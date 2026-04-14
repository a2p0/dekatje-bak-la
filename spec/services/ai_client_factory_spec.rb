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

    it "uses custom model in anthropic request body" do
      stub = stub_request(:post, "https://api.anthropic.com/v1/messages")
        .with(body: hash_including("model" => "claude-haiku-4-5-20251001"))
        .to_return(
          status: 200,
          body: { content: [ { text: "hello" } ] }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      client = described_class.build(provider: :anthropic, api_key: "sk-test", model: "claude-haiku-4-5-20251001")
      client.call(messages: [ { role: "user", content: "test" } ], system: "sys", max_tokens: 100)

      expect(stub).to have_been_requested
    end

    it "uses custom model in google endpoint path" do
      stub = stub_request(:post, "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-pro-preview-06-05:generateContent")
        .to_return(
          status: 200,
          body: { candidates: [ { content: { parts: [ { text: "hello" } ] } } ] }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      client = described_class.build(provider: :google, api_key: "gk-test", model: "gemini-2.5-pro-preview-06-05")
      client.call(messages: [ { role: "user", content: "test" } ], system: "sys", max_tokens: 100)

      expect(stub).to have_been_requested
    end

    it "uses default model when none specified" do
      stub = stub_request(:post, "https://api.anthropic.com/v1/messages")
        .with(body: hash_including("model" => "claude-sonnet-4-6"))
        .to_return(
          status: 200,
          body: { content: [ { text: "hello" } ] }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      client = described_class.build(provider: :anthropic, api_key: "sk-test")
      client.call(messages: [ { role: "user", content: "test" } ], system: "sys", max_tokens: 100)

      expect(stub).to have_been_requested
    end
  end

  describe "#stream" do
    it "raises ArgumentError without a block" do
      client = described_class.build(provider: :anthropic, api_key: "sk-test")
      expect {
        client.stream(messages: [ { role: "user", content: "test" } ], system: "sys")
      }.to raise_error(ArgumentError, "Block required for streaming")
    end

    it "streams tokens from anthropic" do
      sse_chunks = [
        "event: content_block_start\ndata: {\"type\":\"content_block_start\"}\n\n",
        "event: content_block_delta\ndata: {\"type\":\"content_block_delta\",\"delta\":{\"text\":\"Bonjour\"}}\n\n",
        "event: content_block_delta\ndata: {\"type\":\"content_block_delta\",\"delta\":{\"text\":\" !\"}}\n\n",
        "event: message_stop\ndata: {\"type\":\"message_stop\"}\n\n"
      ]

      stub_request(:post, "https://api.anthropic.com/v1/messages")
        .to_return(
          status: 200,
          body: sse_chunks.join,
          headers: { "Content-Type" => "text/event-stream" }
        )

      tokens = []
      client = described_class.build(provider: :anthropic, api_key: "sk-test")
      client.stream(messages: [ { role: "user", content: "test" } ], system: "sys") do |token|
        tokens << token
      end

      expect(tokens).to eq([ "Bonjour", " !" ])
    end

    it "streams tokens from openai" do
      sse_chunks = [
        "data: {\"choices\":[{\"delta\":{\"content\":\"Hello\"}}]}\n\n",
        "data: {\"choices\":[{\"delta\":{\"content\":\" world\"}}]}\n\n",
        "data: [DONE]\n\n"
      ]

      stub_request(:post, "https://api.openai.com/api/v1/chat/completions")
        .to_return(
          status: 200,
          body: sse_chunks.join,
          headers: { "Content-Type" => "text/event-stream" }
        )

      tokens = []
      client = described_class.build(provider: :openai, api_key: "sk-test")
      client.stream(messages: [ { role: "user", content: "test" } ], system: "sys") do |token|
        tokens << token
      end

      expect(tokens).to eq([ "Hello", " world" ])
    end

    it "streams tokens from google" do
      sse_chunks = [
        "data: {\"candidates\":[{\"content\":{\"parts\":[{\"text\":\"Salut\"}]}}]}\n\n",
        "data: {\"candidates\":[{\"content\":{\"parts\":[{\"text\":\" toi\"}]}}]}\n\n"
      ]

      stub_request(:post, "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:streamGenerateContent?alt=sse")
        .to_return(
          status: 200,
          body: sse_chunks.join,
          headers: { "Content-Type" => "text/event-stream" }
        )

      tokens = []
      client = described_class.build(provider: :google, api_key: "gk-test")
      client.stream(messages: [ { role: "user", content: "test" } ], system: "sys") do |token|
        tokens << token
      end

      expect(tokens).to eq([ "Salut", " toi" ])
    end

    it "raises on API error" do
      stub_request(:post, "https://api.anthropic.com/v1/messages")
        .to_return(status: 401, body: "Unauthorized")

      client = described_class.build(provider: :anthropic, api_key: "bad-key")
      expect {
        client.stream(messages: [ { role: "user", content: "test" } ], system: "sys") { |_t| }
      }.to raise_error(/API error 401/)
    end
  end
end
