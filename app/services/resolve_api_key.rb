class ResolveApiKey
  class NoApiKeyError < StandardError; end

  def self.call(user:)
    if user.api_key.present?
      { api_key: user.api_key, provider: user.api_provider.to_sym }
    elsif ENV["ANTHROPIC_API_KEY"].present?
      { api_key: ENV["ANTHROPIC_API_KEY"], provider: :anthropic }
    else
      raise NoApiKeyError, "Aucune clé API disponible (ni enseignant ni serveur)"
    end
  end
end
