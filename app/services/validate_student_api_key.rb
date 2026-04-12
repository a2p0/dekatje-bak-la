class ValidateStudentApiKey
  class InvalidApiKeyError < StandardError; end

  def self.call(provider:, api_key:, model:) = new(provider:, api_key:, model:).call

  def initialize(provider:, api_key:, model:)
    @provider = provider
    @api_key = api_key
    @model = model
  end

  def call
    client = AiClientFactory.build(provider: @provider, api_key: @api_key)
    client.call(
      messages: [ { role: "user", content: "Réponds OK" } ],
      system: "Réponds uniquement OK.",
      max_tokens: 10,
      temperature: 0
    )
    true
  rescue AiClientFactory::UnknownProviderError
    raise InvalidApiKeyError, "Provider inconnu : #{@provider}"
  rescue Faraday::TimeoutError
    raise InvalidApiKeyError, "Timeout — le serveur n'a pas répondu."
  rescue InvalidApiKeyError
    raise
  rescue => e
    raise InvalidApiKeyError, e.message
  end
end
