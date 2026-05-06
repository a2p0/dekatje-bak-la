module Tutor
  # Pure function: (trace, answer_type, expected_value?) → Symbol
  # Phases possible: :fresh :armed :debug :close :done
  # Never persisted. Read-only signal for ChipsPresenter and sim metrics.
  class DerivePhase
    CLOSE_TOLERANCE = 0.05  # 5% relative tolerance for numeric :close

    def self.call(trace:, answer_type:, expected_value: nil)
      return :done   if done?(trace)
      return :close  if close?(trace, answer_type, expected_value)
      return :debug  if has_incorrect_attempt?(trace)
      return :armed  if armed?(trace)

      :fresh
    end

    def self.done?(trace)
      trace.events.any? do |e|
        e["type"] == "viewed_correction" ||
          (e["type"] == "student_attempt" && e["verdict"] == "correct") ||
          e["type"] == "marked_done"
      end
    end

    def self.armed?(trace)
      trace.events.any? do |e|
        e["type"] == "viewed_data_hints" ||
          (e["type"] == "tutor_gave" && %w[formule structure élimination critère].include?(e["what"]))
      end
    end

    def self.has_incorrect_attempt?(trace)
      trace.events.any? do |e|
        e["type"] == "student_attempt" && e["verdict"] == "incorrect"
      end
    end

    def self.close?(trace, answer_type, expected_value)
      return false unless answer_type == "calcul"
      return false if expected_value.nil?

      last_attempt = trace.events.reverse.find { |e| e["type"] == "student_attempt" }
      return false unless last_attempt && last_attempt["content"]

      attempt_value = numeric_value(last_attempt["content"])
      expected      = numeric_value(expected_value)
      return false if attempt_value.nil? || expected.nil? || expected.zero?

      ((attempt_value - expected).abs / expected.abs) <= CLOSE_TOLERANCE
    end

    def self.numeric_value(raw)
      Float(raw.to_s.tr(",", ".").gsub(/[^\d.\-]/, ""))
    rescue ArgumentError, TypeError
      nil
    end
  end
end
