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
        message_count_user:        @conversation.messages.where(role: :user).count,
        first_turn_with_transition: first_turn_with_transition,
        action_verb_ratio_guiding:  action_verb_ratio_guiding
      }
    end

    private

    def first_turn_with_transition
      return nil if @phase_per_turn.nil?

      @phase_per_turn.each_with_index do |phase, i|
        next if i.zero?
        return i if phase != @phase_per_turn[i - 1] && phase != "idle"
      end
      nil
    end

    # Ratio of assistant messages emitted during guiding phase that start
    # with an action verb (from ACTION_VERBS) — measures H2.
    # Returns nil when phase_per_turn is missing OR when guiding phase
    # was never reached (no division by zero, distinguishable from "0 verbs").
    def action_verb_ratio_guiding
      return nil if @phase_per_turn.nil?

      guiding_messages = @assistant_messages.to_a.each_with_index.select do |_msg, idx|
        @phase_per_turn[idx + 1] == "guiding"
      end
      return nil if guiding_messages.empty?

      matching = guiding_messages.count { |msg, _idx| starts_with_action_verb?(msg.content) }
      (matching.to_f / guiding_messages.size).round(2)
    end

    def starts_with_action_verb?(content)
      first_word = content.to_s.strip.downcase.split(/\s+/).first.to_s
      first_word = first_word.gsub(/[[:punct:]]+$/, "")
      ACTION_VERBS.include?(first_word)
    end


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
