module Tutor
  class BroadcastMessage
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
          conversation:      @conversation,
          question:          @question,
          access_code:       @access_code,
          next_question_url: nil
        }
      )
    rescue => e
      Rails.logger.error("[BroadcastMessage] chips render failed: #{e.message}")
      ""
    end
  end
end
