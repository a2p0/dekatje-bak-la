class ResolveApiKey
  class NoApiKeyError < StandardError; end
  Result = Struct.new(:api_key, :provider, keyword_init: true)

  def self.call(user:) = new(user:).call

  def initialize(user:)
    @user = user
  end

  def call
    if @user.api_key.present?
      Result.new(api_key: @user.api_key, provider: @user.api_provider.to_sym)
    elsif ENV["OPENROUTER_API_KEY"].present?
      Result.new(api_key: ENV["OPENROUTER_API_KEY"], provider: :openrouter)
    elsif ENV["ANTHROPIC_API_KEY"].present?
      Result.new(api_key: ENV["ANTHROPIC_API_KEY"], provider: :anthropic)
    else
      raise NoApiKeyError, "Aucune clé API disponible (ni enseignant ni serveur)"
    end
  end
end
