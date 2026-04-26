class ResolveTutorApiKey
  DEFAULT_MODEL = {
    "anthropic"  => "claude-3-5-haiku-20241022",
    "openrouter" => "openai/gpt-4o-mini",
    "openai"     => "gpt-4o-mini",
    "google"     => "gemini-2.0-flash"
  }.freeze

  def initialize(student:, classroom:)
    @student   = student
    @classroom = classroom
  end

  def call
    if @student.use_personal_key? && @student.api_key.present?
      provider = @student.api_provider.to_s
      return { api_key: @student.api_key, provider: provider, model: @student.effective_model }
    end

    if @classroom.tutor_free_mode_enabled? && @classroom.owner.openrouter_api_key.present?
      key = @classroom.owner.openrouter_api_key
      return { api_key: key, provider: "openrouter", model: DEFAULT_MODEL["openrouter"] }
    end

    raise Tutor::NoApiKeyError
  end
end
