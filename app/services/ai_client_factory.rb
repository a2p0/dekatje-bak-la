class AiClientFactory
  class UnknownProviderError < StandardError; end

  PROVIDERS = {
    anthropic:   { base_url: "https://api.anthropic.com",                       auth_header: "x-api-key" },
    openrouter:  { base_url: "https://openrouter.ai",                           auth_header: "Authorization" },
    openai:      { base_url: "https://api.openai.com",                          auth_header: "Authorization" },
    google:      { base_url: "https://generativelanguage.googleapis.com",       auth_header: "x-goog-api-key" }
  }.freeze

  DEFAULT_MODELS = {
    anthropic:  "claude-sonnet-4-5-20251001",
    openrouter: "anthropic/claude-haiku-4-5",
    openai:     "gpt-4o-mini",
    google:     "gemini-2.0-flash"
  }.freeze

  def self.build(provider:, api_key:, model: nil)
    config = PROVIDERS[provider.to_sym]
    raise UnknownProviderError, "Unknown provider: #{provider}" unless config

    new(provider: provider.to_sym, api_key: api_key, config: config, model: model)
  end

  def initialize(provider:, api_key:, config:, model: nil)
    @provider = provider
    @api_key  = api_key
    @config   = config
    @model    = model || DEFAULT_MODELS[@provider]
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

  def stream(messages:, system:, max_tokens: 4096, temperature: 0.7, &block)
    raise ArgumentError, "Block required for streaming" unless block_given?

    connection = Faraday.new(url: @config[:base_url]) do |f|
      f.request :json
      f.options.timeout = 120
    end

    headers = build_headers
    body    = build_stream_body(messages: messages, system: system, max_tokens: max_tokens, temperature: temperature)
    path    = stream_endpoint_path
    buffer  = ""

    response = connection.post(path, body.to_json, headers) do |req|
      req.options.on_data = proc do |chunk, _overall_received_bytes, _env|
        buffer += chunk
        buffer = parse_stream_buffer(buffer, &block)
      end
    end

    raise "API error #{response.status}: #{response.body}" unless response.status == 200
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
      { model: @model, system: system, messages: messages, max_tokens: max_tokens, temperature: temperature }
    when :openrouter
      { model: @model, messages: [ { role: "system", content: system } ] + messages, max_tokens: max_tokens, temperature: temperature }
    when :openai
      { model: @model, messages: [ { role: "system", content: system } ] + messages, max_tokens: max_tokens, temperature: temperature }
    when :google
      { contents: messages.map { |m| { role: m[:role], parts: [ { text: m[:content] } ] } }, system_instruction: { parts: [ { text: system } ] }, generationConfig: { maxOutputTokens: max_tokens, temperature: temperature } }
    end
  end

  def endpoint_path
    case @provider
    when :anthropic then "/v1/messages"
    when :openrouter, :openai then "/api/v1/chat/completions"
    when :google then "/v1beta/models/#{@model}:generateContent"
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

  def build_stream_body(messages:, system:, max_tokens:, temperature:)
    body = build_body(messages: messages, system: system, max_tokens: max_tokens, temperature: temperature)
    case @provider
    when :anthropic
      body.merge(stream: true)
    when :openrouter, :openai
      body.merge(stream: true)
    when :google
      body
    end
  end

  def stream_endpoint_path
    case @provider
    when :anthropic then "/v1/messages"
    when :openrouter, :openai then "/api/v1/chat/completions"
    when :google then "/v1beta/models/#{@model}:streamGenerateContent?alt=sse"
    end
  end

  def parse_stream_buffer(buffer, &block)
    while (line_end = buffer.index("\n"))
      line = buffer.slice!(0, line_end + 1).strip
      next if line.empty?

      parse_stream_line(line, &block)
    end
    buffer
  end

  def parse_stream_line(line, &block)
    case @provider
    when :anthropic
      parse_anthropic_stream_line(line, &block)
    when :openrouter, :openai
      parse_openai_stream_line(line, &block)
    when :google
      parse_google_stream_line(line, &block)
    end
  end

  def parse_anthropic_stream_line(line, &block)
    return unless line.start_with?("data: ")

    json_str = line.sub("data: ", "")
    return if json_str == "[DONE]"

    data = JSON.parse(json_str)
    if data["type"] == "content_block_delta" && data.dig("delta", "text")
      yield data["delta"]["text"]
    end
  rescue JSON::ParserError
    # Skip malformed lines
  end

  def parse_openai_stream_line(line, &block)
    return unless line.start_with?("data: ")

    json_str = line.sub("data: ", "")
    return if json_str == "[DONE]"

    data = JSON.parse(json_str)
    content = data.dig("choices", 0, "delta", "content")
    yield content if content
  rescue JSON::ParserError
    # Skip malformed lines
  end

  def parse_google_stream_line(line, &block)
    return unless line.start_with?("data: ")

    json_str = line.sub("data: ", "")
    data = JSON.parse(json_str)
    text = data.dig("candidates", 0, "content", "parts", 0, "text")
    yield text if text
  rescue JSON::ParserError
    # Skip malformed lines
  end
end
