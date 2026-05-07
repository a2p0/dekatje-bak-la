module Tutor
  # Broadcasts the final ActionCable payload for a tutor turn:
  # - message metadata (id, role, content, streaming_finished_at)
  # - chips_html rendered from current trace + answer_type
  # Streaming chunks themselves are sent by Tutor::CallLlm directly.
  class BroadcastDone
    def self.call(conversation:, message:, question:, access_code:)
      new(conversation: conversation, message: message, question: question, access_code: access_code).call
    end

    def initialize(conversation:, message:, question:, access_code:)
      @conversation = conversation
      @message      = message
      @question     = question
      @access_code  = access_code
    end

    def call
      ActionCable.server.broadcast(
        "conversation_#{@conversation.id}",
        {
          type: "done",
          message: {
            id:                    @message.id,
            role:                  @message.role,
            content:               @message.content,
            streaming_finished:    @message.streaming_finished_at.present?,
            streaming_finished_at: @message.streaming_finished_at&.iso8601
          },
          chips_html: render_chips_html
        }
      )
      Result.ok
    end

    private

    def render_chips_html
      return "" unless @question && @access_code.present?

      ApplicationController.renderer.render(
        partial: "student/conversations/chips",
        locals:  {
          conversation: @conversation,
          question:     @question,
          access_code:  @access_code,
          chips:        chips_for_view
        }
      )
    rescue => e
      Rails.logger.error("[Tutor::BroadcastDone] chips render failed: #{e.message}")
      ""
    end

    def chips_for_view
      trace = @conversation.tutor_state.trace_for(@question.id)
      Tutor::ChipsPresenter.call(
        trace:          trace,
        answer_type:    @question.answer_type.to_s,
        expected_value: nil  # could be wired later if structured_correction has a numeric final
      )
    end
  end
end
