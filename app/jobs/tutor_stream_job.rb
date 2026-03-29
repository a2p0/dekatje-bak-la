# app/jobs/tutor_stream_job.rb
class TutorStreamJob < ApplicationJob
  queue_as :default

  def perform(conversation_id)
    conversation = Conversation.find(conversation_id)
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
  rescue Faraday::UnauthorizedError, RuntimeError => e
    handle_error(conversation, e)
  rescue Faraday::TimeoutError => e
    handle_error(conversation, e, "Le serveur n'a pas repondu. Reessayez.")
  rescue StandardError => e
    handle_error(conversation, e, "Une erreur est survenue. Reessayez.")
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
      "Cle API invalide. Verifiez vos reglages."
    when /402/, /429/
      "Credits insuffisants sur votre compte."
    when /timeout/i
      "Le serveur n'a pas repondu. Reessayez."
    else
      "Erreur de communication avec l'IA. Reessayez."
    end
  end
end
