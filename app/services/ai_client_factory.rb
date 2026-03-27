class AiClientFactory
  class UnknownProviderError < StandardError; end

  PROVIDERS = {
    anthropic:   { base_url: "https://api.anthropic.com",                       auth_header: "x-api-key" },
    openrouter:  { base_url: "https://openrouter.ai",                           auth_header: "Authorization" },
    openai:      { base_url: "https://api.openai.com",                          auth_header: "Authorization" },
    google:      { base_url: "https://generativelanguage.googleapis.com",       auth_header: "x-goog-api-key" }
  }.freeze

  def self.build(provider:, api_key:)
    config = PROVIDERS[provider.to_sym]
    raise UnknownProviderError, "Unknown provider: #{provider}" unless config

    new(provider: provider.to_sym, api_key: api_key, config: config)
  end

  def initialize(provider:, api_key:, config:)
    @provider = provider
    @api_key  = api_key
    @config   = config
  end

  def call(messages:, system:, max_tokens: 4096, temperature: 0.2)
    connection = Faraday.new(url: @config[:base_url]) do |f|
      f.request :json
      f.response :json
      f.options.timeout = 60
    end

    headers = build_headers
    body    = build_body(messages: messages, system: system, max_tokens: max_tokens, temperature: temperature)

    response = connection.post(endpoint_path, body, headers)

    raise "API error #{response.status}: #{response.body}" unless response.success?

    extract_text(response.body)
  end

  private

  def build_headers
    case @provider
    when :anthropic
      {
        "x-api-key"         => @api_key,
        "anthropic-version" => "2023-06-01",
        "Content-Type"      => "application/json"
      }
    when :openrouter, :openai
      { "Authorization" => "Bearer #{@api_key}", "Content-Type" => "application/json" }
    when :google
      { "x-goog-api-key" => @api_key, "Content-Type" => "application/json" }
    end
  end

  def build_body(messages:, system:, max_tokens:, temperature:)
    case @provider
    when :anthropic
      { model: "claude-sonnet-4-5-20251001", system: system, messages: messages, max_tokens: max_tokens, temperature: temperature }
    when :openrouter
      { model: "anthropic/claude-haiku-4-5", messages: [ { role: "system", content: system } ] + messages, max_tokens: max_tokens, temperature: temperature }
    when :openai
      { model: "gpt-4o-mini", messages: [ { role: "system", content: system } ] + messages, max_tokens: max_tokens, temperature: temperature }
    when :google
      { contents: messages.map { |m| { role: m[:role], parts: [ { text: m[:content] } ] } }, system_instruction: { parts: [ { text: system } ] }, generationConfig: { maxOutputTokens: max_tokens, temperature: temperature } }
    end
  end

  def endpoint_path
    case @provider
    when :anthropic then "/v1/messages"
    when :openrouter, :openai then "/api/v1/chat/completions"
    when :google then "/v1beta/models/gemini-2.0-flash:generateContent"
    end
  end

  def extract_text(body)
    case @provider
    when :anthropic
      body.dig("content", 0, "text")
    when :openrouter, :openai
      body.dig("choices", 0, "message", "content")
    when :google
      body.dig("candidates", 0, "content", "parts", 0, "text")
    end
  end
end
