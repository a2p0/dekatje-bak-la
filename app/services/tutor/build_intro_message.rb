module Tutor
  class BuildIntroMessage
    def self.call(question:, conversation:)
      new(question: question, conversation: conversation).call
    end

    def initialize(question:, conversation:)
      @question     = question
      @conversation = conversation
    end

    def call
      return Result.ok if intro_seen?

      content = "Question #{@question.number} — #{@question.points} pt#{@question.points > 1 ? 's' : ''}. #{@question.label}"
      @conversation.messages.create!(kind: :intro, role: :assistant, content: content)
      mark_intro_seen!

      Result.ok(content: content)
    end

    private

    def intro_seen?
      qs = @conversation.tutor_state.question_states[@question.id.to_s]
      qs&.intro_seen == true
    end

    def mark_intro_seen!
      current_qs = @conversation.tutor_state.question_states
      existing   = current_qs[@question.id.to_s] || QuestionState.new(
        step: nil, hints_used: 0, last_confidence: nil,
        error_types: [], completed_at: nil, intro_seen: false
      )
      updated_qs = existing.with(intro_seen: true)
      new_ts     = @conversation.tutor_state.with(
        question_states: current_qs.merge(@question.id.to_s => updated_qs)
      )
      Tutor::UpdateTutorState.call(conversation: @conversation, tutor_state: new_ts)
    end
  end
end
