module Tutor
  class BuildWelcomeMessage
    FALLBACK_PHRASE = "Lance-toi quand tu es prêt !"

    SYSTEM_PROMPT = <<~PROMPT.freeze
      Tu génères UNE SEULE phrase courte (max 15 mots) d'encouragement pour un élève de Terminale STI2D.
      La phrase ne pose pas de question, ne demande rien à l'élève, et ne mentionne pas la correction.
      Exemples valides : 'Tu peux le faire !' / 'Bonne chance pour ce sujet !' / 'Prends ton temps, tu y arriveras.'
    PROMPT

    def self.call(subject:, conversation:, api_key_data:)
      new(subject: subject, conversation: conversation, api_key_data: api_key_data).call
    end

    def initialize(subject:, conversation:, api_key_data:)
      @subject       = subject
      @conversation  = conversation
      @api_key_data  = api_key_data
    end

    def call
      phrase     = llm_phrase
      n          = Question.kept.joins(:part).where(parts: { subject_id: @subject.id }).count
      content    = "Bonjour ! Tu vas travailler sur #{@subject.title} (#{n} questions). #{phrase}"

      @conversation.messages.create!(kind: :welcome, role: :assistant, content: content)
      new_state = @conversation.tutor_state.with(welcome_sent: true)
      Tutor::UpdateTutorState.call(conversation: @conversation, tutor_state: new_state)

      Result.ok(content: content)
    end

    private

    def llm_phrase
      configure_ruby_llm
      chat = RubyLLM::Chat.new(model: @api_key_data[:model])
      chat.with_instructions(SYSTEM_PROMPT)
      chat.with_params(max_tokens: 30)
      response = chat.ask("Génère une phrase d'encouragement.")
      response.content.to_s.strip.presence || FALLBACK_PHRASE
    rescue => _e
      FALLBACK_PHRASE
    end

    def configure_ruby_llm
      RubyLLM.configure do |config|
        case @api_key_data[:provider]
        when "anthropic"
          config.anthropic_api_key = @api_key_data[:api_key]
        when "openrouter"
          config.openrouter_api_key = @api_key_data[:api_key]
        when "openai"
          config.openai_api_key = @api_key_data[:api_key]
        when "google"
          config.gemini_api_key = @api_key_data[:api_key]
        end
      end
    end
  end
end
