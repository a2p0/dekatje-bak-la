module TutorSimulation
  # 062: structural metrics computed from QuestionTrace events.
  # No phase-rank, no spotting concepts. Aligned with redesign goals:
  # - resolution_rate (main metric)
  # - cap_violations (target = 0)
  # - mean_help_steps_before_resolution
  # - proactive_help_rate
  # - correct_attempts_after_help_rate
  # - attempts_per_question
  # - correction_view_rate
  # - mean_turns_to_resolution
  class StructuralMetrics
    def self.compute(conversation:, question_ids:)
      new(conversation: conversation, question_ids: question_ids).compute
    end

    def initialize(conversation:, question_ids:)
      @conversation = conversation
      @question_ids = Array(question_ids).map(&:to_i)
    end

    def compute
      traces = @question_ids.map { |qid| @conversation.tutor_state.trace_for(qid) }

      {
        resolution_rate:                   resolution_rate(traces),
        cap_violations:                    cap_violations(traces),
        mean_help_steps_before_resolution: mean_help_steps_before_resolution(traces),
        proactive_help_rate:               proactive_help_rate(traces),
        correct_attempts_after_help_rate:  correct_attempts_after_help_rate(traces),
        attempts_per_question:             attempts_per_question(traces),
        correction_view_rate:              correction_view_rate(traces),
        mean_turns_to_resolution:          mean_turns_to_resolution(traces)
      }
    end

    private

    def resolution_rate(traces)
      return 0.0 if traces.empty?
      resolved = traces.count { |t| resolved_without_correction?(t) }
      (resolved.to_f / traces.size).round(3)
    end

    def resolved_without_correction?(trace)
      first_correct = trace.events.index { |e| e["type"] == "student_attempt" && e["verdict"] == "correct" }
      first_view    = trace.events.index { |e| e["type"] == "viewed_correction" }
      return false unless first_correct
      first_view.nil? || first_correct < first_view
    end

    def cap_violations(traces)
      traces.sum { |t| t.events.count { |e| e["type"] == "cap_violation" } }
    end

    def mean_help_steps_before_resolution(traces)
      counts = traces.filter_map do |t|
        idx = t.events.index { |e| e["type"] == "student_attempt" && e["verdict"] == "correct" }
        next nil if idx.nil?
        t.events[0...idx].count { |e| e["type"] == "tutor_gave" }
      end
      return 0.0 if counts.empty?
      (counts.sum.to_f / counts.size).round(3)
    end

    def proactive_help_rate(traces)
      total_gives = traces.sum { |t| t.events.count { |e| e["type"] == "tutor_gave" } }
      return 0.0 if total_gives.zero?

      proactive_count = traces.sum do |t|
        t.events.each_with_index.count do |e, i|
          e["type"] == "tutor_gave" && t.events[0...i].none? { |prev| prev["type"] == "student_attempt" }
        end
      end
      (proactive_count.to_f / total_gives).round(3)
    end

    def correct_attempts_after_help_rate(traces)
      correct_attempts = traces.sum { |t| t.events.count { |e| e["type"] == "student_attempt" && e["verdict"] == "correct" } }
      return 0.0 if correct_attempts.zero?

      after_help = traces.sum do |t|
        t.events.each_with_index.count do |e, i|
          e["type"] == "student_attempt" && e["verdict"] == "correct" &&
            t.events[0...i].any? { |prev| prev["type"] == "tutor_gave" }
        end
      end
      (after_help.to_f / correct_attempts).round(3)
    end

    def attempts_per_question(traces)
      return 0.0 if traces.empty?
      total = traces.sum { |t| t.events.count { |e| e["type"] == "student_attempt" } }
      (total.to_f / traces.size).round(3)
    end

    def correction_view_rate(traces)
      return 0.0 if traces.empty?
      viewed = traces.count { |t| t.events.any? { |e| e["type"] == "viewed_correction" } }
      (viewed.to_f / traces.size).round(3)
    end

    def mean_turns_to_resolution(traces)
      turns = traces.filter_map do |t|
        idx = t.events.index { |e| e["type"] == "student_attempt" && e["verdict"] == "correct" }
        next nil if idx.nil?
        t.events[0..idx].count { |e| e["type"] == "student_attempt" }
      end
      return 0.0 if turns.empty?
      (turns.sum.to_f / turns.size).round(3)
    end
  end
end
