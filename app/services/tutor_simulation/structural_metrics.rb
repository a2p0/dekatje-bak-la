module TutorSimulation
  # Deterministic metrics computed from a Conversation after a sim run.
  # Cheap, no LLM call, complementary to Judge's qualitative scoring.
  class StructuralMetrics
    PHASE_RANK = {
      "idle"       => 0,
      "greeting"   => 1,
      "reading"    => 2,
      "spotting"   => 3,
      "guiding"    => 4,
      "validating" => 5,
      "feedback"   => 6,
      "ended"      => 7
    }.freeze

    ACTION_VERBS = %w[identifie repère cite relève compare calcule].freeze
    DT_DR_REGEX  = /\b(?:DT|DR)\d+\b/i.freeze
    SHORT_MESSAGE_WORD_THRESHOLD = 60

    def self.compute(conversation:, phase_per_turn: nil)
      new(conversation: conversation, phase_per_turn: phase_per_turn).compute
    end

    def initialize(conversation:, phase_per_turn: nil)
      @conversation = conversation
      @phase_per_turn = phase_per_turn
      @assistant_messages = conversation.messages.where(role: :assistant).order(:created_at)
    end

    def compute
      {
        final_phase:               @conversation.tutor_state.current_phase,
        phase_rank:                PHASE_RANK.fetch(@conversation.tutor_state.current_phase, 0),
        avg_message_length_words:  avg_message_length_words,
        open_question_ratio:       open_question_ratio,
        regex_intercepts:          regex_intercept_count,
        hints_used:                @conversation.tutor_state.question_states.values.sum { |qs| qs.hints_used.to_i },
        message_count_assistant:   @assistant_messages.count,
        message_count_user:        @conversation.messages.where(role: :user).count
      }
    end

    private

    def avg_message_length_words
      return 0 if @assistant_messages.empty?

      total = @assistant_messages.sum { |m| m.content.to_s.split.size }
      (total.to_f / @assistant_messages.count).round(1)
    end

    def open_question_ratio
      return 0.0 if @assistant_messages.empty?

      ending_with_question = @assistant_messages.count { |m| m.content.to_s.strip.end_with?("?") }
      (ending_with_question.to_f / @assistant_messages.count).round(2)
    end

    # FilterSpottingOutput::NEUTRAL_RELAUNCH replaces the LLM output when a
    # forbidden pattern (DT/DR mentions, numerical values) is detected.
    # Counting how many assistant messages got replaced reveals leaks the
    # tutor tried to make.
    def regex_intercept_count
      neutral = Tutor::FilterSpottingOutput::NEUTRAL_RELAUNCH
      @assistant_messages.where(content: neutral).count
    end
  end
end
