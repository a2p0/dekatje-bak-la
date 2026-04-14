module Tutor
  class BroadcastMessage
    def self.call(conversation:, message:)
      new(conversation: conversation, message: message).call
    end

    def initialize(conversation:, message:)
      @conversation = conversation
      @message      = message
    end

    def call
      ActionCable.server.broadcast(
        "conversation_#{@conversation.id}",
        {
          message: {
            id:                    @message.id,
            role:                  @message.role,
            content:               @message.content,
            streaming_finished:    @message.streaming_finished_at.present?,
            streaming_finished_at: @message.streaming_finished_at&.iso8601
          }
        }
      )
      Result.ok
    end
  end
end
