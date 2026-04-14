module Tutor
  class InjectDataHints
    TERMINAL_OUTCOMES = %w[success forced_reveal].freeze

    def self.call(conversation:, question:, outcome:)
      new(conversation: conversation, question: question, outcome: outcome).call
    end

    def initialize(conversation:, question:, outcome:)
      @conversation = conversation
      @question     = question
      @outcome      = outcome
    end

    def call
      return Result.ok unless terminal_outcome?

      hints = @question.answer&.data_hints.to_a
      return Result.ok if hints.empty?

      rendered = render_data_hints(hints)
      msg = @conversation.messages.create!(
        role:        :system,
        content:     rendered,
        chunk_index: 0
      )

      ActionCable.server.broadcast(
        "conversation_#{@conversation.id}",
        {
          type:       "data_hints",
          message_id: msg.id,
          html:       rendered
        }
      )

      Result.ok
    end

    private

    def terminal_outcome?
      TERMINAL_OUTCOMES.include?(@outcome.to_s)
    end

    def render_data_hints(hints)
      ApplicationController.render(
        DataHintsComponent.new(data_hints: hints),
        layout: false
      )
    end
  end
end
