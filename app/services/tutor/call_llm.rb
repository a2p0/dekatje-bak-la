module Tutor
  class CallLlm
    CHUNK_PERSIST_TOKENS = 50

    def self.call(conversation:, system_prompt:, messages:, student_message:)
      new(
        conversation:    conversation,
        system_prompt:   system_prompt,
        messages:        messages,
        student_message: student_message
      ).call
    end

    def initialize(conversation:, system_prompt:, messages:, student_message:)
      @conversation    = conversation
      @system_prompt   = system_prompt
      @messages        = messages
      @student_message = student_message
    end

    def call
      credentials = resolve_credentials
      if credentials[:error]
        broadcast_error(credentials[:error])
        return Result.err(credentials[:error])
      end

      configure_ruby_llm(credentials)

      full_content  = +""
      tool_calls    = []
      buffer_tokens = 0
      last_persist  = Time.current

      chat = RubyLLM::Chat.new(model: credentials[:model])
      chat.with_instructions(@system_prompt)

      response = chat.ask(@messages) do |chunk|
        delta = chunk.content.to_s
        full_content << delta
        if chunk.tool_calls.present?
          tool_calls = chunk.tool_calls.respond_to?(:values) ? chunk.tool_calls.values : chunk.tool_calls
        end

        if delta.present?
          ActionCable.server.broadcast(
            "conversation_#{@conversation.id}",
            { type: "token", message_id: @student_message.id, token: delta }
          )
        end

        buffer_tokens += 1
        now = Time.current
        if buffer_tokens >= CHUNK_PERSIST_TOKENS || (now - last_persist) >= 0.25
          @student_message.update_columns(
            content:     full_content,
            chunk_index: @student_message.chunk_index + buffer_tokens
          )
          buffer_tokens = 0
          last_persist  = now
        end
      end

      @student_message.update!(
        content:               full_content,
        tokens_in:             response.respond_to?(:input_tokens) ? response.input_tokens.to_i : 0,
        tokens_out:            response.respond_to?(:output_tokens) ? response.output_tokens.to_i : 0,
        streaming_finished_at: Time.current
      )

      Result.ok(full_content: full_content, tool_calls: Array(tool_calls))
    rescue Tutor::NoApiKeyError => e
      broadcast_error(e.message)
      Result.err(e.message)
    rescue => e
      broadcast_error("Erreur LLM : #{e.message}")
      Result.err("Erreur LLM : #{e.message}")
    end

    def broadcast_error(message)
      ActionCable.server.broadcast(
        "conversation_#{@conversation.id}",
        { type: "error", error: message }
      )
    end

    private

    def resolve_credentials
      ResolveTutorApiKey.new(
        student:   @conversation.student,
        classroom: @conversation.student.classroom
      ).call
    rescue Tutor::NoApiKeyError => e
      { error: e.message }
    end

    def configure_ruby_llm(credentials)
      RubyLLM.configure do |config|
        case credentials[:provider]
        when "anthropic"
          config.anthropic_api_key = credentials[:api_key]
        when "openrouter"
          config.openrouter_api_key = credentials[:api_key]
        when "openai"
          config.openai_api_key = credentials[:api_key]
        when "google"
          config.gemini_api_key = credentials[:api_key]
        end
      end
    end
  end
end
