module Tutor
  class UpdateTutorState
    def self.call(conversation:, tutor_state:)
      new(conversation: conversation, tutor_state: tutor_state).call
    end

    def initialize(conversation:, tutor_state:)
      @conversation = conversation
      @tutor_state  = tutor_state
    end

    def call
      @conversation.update!(tutor_state: @tutor_state)
      Result.ok
    rescue ActiveRecord::RecordInvalid => e
      Result.err("Impossible de persister le TutorState : #{e.message}")
    end
  end
end
