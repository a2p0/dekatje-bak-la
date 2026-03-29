class ValidateStudentApiKey
  def self.call(provider:, api_key:, model:)
    client = AiClientFactory.build(provider: provider, api_key: api_key)
    client.call(
      messages: [ { role: "user", content: "Réponds OK" } ],
      system: "Réponds uniquement OK.",
      max_tokens: 10,
      temperature: 0
    )
    { valid: true }
  rescue AiClientFactory::UnknownProviderError
    { valid: false, error: "Provider inconnu : #{provider}" }
  rescue Faraday::TimeoutError
    { valid: false, error: "Timeout — le serveur n'a pas répondu." }
  rescue => e
    { valid: false, error: e.message }
  end
end
