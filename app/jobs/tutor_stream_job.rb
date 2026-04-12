# app/jobs/tutor_stream_job.rb
class TutorStreamJob < ApplicationJob
  queue_as :default

  def perform(conversation_id)
    conversation = Conversation.find(conversation_id)
    return if conversation.messages.last&.dig("role") == "assistant"

    student = conversation.student
    question = conversation.question

    conversation.update!(streaming: true)

    system_prompt = BuildTutorPrompt.call(question: question, student: student)

    client = AiClientFactory.build(
      provider: student.api_provider,
      api_key: student.api_key,
      model: student.effective_model
    )

    full_response = ""

    client.stream(
      messages: conversation.messages_for_api,
      system: system_prompt,
      max_tokens: 2048,
      temperature: 0.7
    ) do |token|
      full_response += token
      ActionCable.server.broadcast("conversation_#{conversation.id}", { token: token })
    end

    conversation.add_message!(role: "assistant", content: full_response)
    conversation.update!(
      streaming: false,
      tokens_used: conversation.tokens_used + estimate_tokens(full_response),
      provider_used: student.api_provider
    )

    ActionCable.server.broadcast("conversation_#{conversation.id}", { done: true })
  rescue RuntimeError => e
    if e.message.match?(/429|529|503/) && (@retries ||= 0) < 2
      @retries += 1
      sleep(@retries * 3)
      retry
    end
    handle_error(conversation, e)
  rescue Faraday::UnauthorizedError => e
    handle_error(conversation, e)
  rescue Faraday::TimeoutError => e
    handle_error(conversation, e, "Le serveur n'a pas répondu. Réessayez.")
  rescue StandardError => e
    handle_error(conversation, e, "Une erreur est survenue. Réessayez.")
  end

  private

  def estimate_tokens(text)
    (text.length / 4.0).ceil
  end

  def handle_error(conversation, error, custom_message = nil)
    message = custom_message || error_message_for(error)
    conversation.update!(streaming: false)
    ActionCable.server.broadcast("conversation_#{conversation.id}", { error: message })
    Rails.logger.error("[TutorStreamJob] #{error.class}: #{error.message}")
  end

  def error_message_for(error)
    case error.message
    when /401/
      "Clé API invalide. Vérifiez vos réglages."
    when /402/
      "Crédits insuffisants sur votre compte."
    when /429/
      "Trop de requêtes. Réessayez dans quelques secondes."
    when /529/, /503/
      "Le service IA est temporairement surchargé. Réessayez."
    when /timeout/i
      "Le serveur n'a pas répondu. Réessayez."
    else
      "Erreur de communication avec l'IA. Réessayez."
    end
  end
end
