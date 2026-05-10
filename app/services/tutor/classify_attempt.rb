module Tutor
  # Deterministic verdict classifier for student_attempt events.
  # Compares the student's textual content against the question's
  # structured_correction.final_answers. No LLM call.
  #
  # Returns one of:
  #   "correct"   if any final_answer "value" appears in the student content (after normalization)
  #   "unknown"   otherwise (or if structured_correction missing)
  #
  # MVP scope: substring match after normalization (downcase, strip, remove
  # spaces and common units). No numeric tolerance, no rephrasing detection.
  # Acceptable trade-off for sim runs where simulated students reply with
  # explicit numerical values.
  class ClassifyAttempt
    UNITS_TO_STRIP = /\b(?:litres?|l|kg|kw|kwh|w|joules?|j|m\/s|km\/h|h|s|m²|m2|m|km|n|°c|°)\b/i.freeze

    def self.call(student_content:, question:)
      new(student_content: student_content, question: question).call
    end

    def initialize(student_content:, question:)
      @content  = student_content.to_s
      @question = question
    end

    def call
      sc = @question.answer&.structured_correction
      return "unknown" if sc.blank?

      finals = Array(sc["final_answers"])
      return "unknown" if finals.empty?

      normalized_content = normalize(@content)
      return "unknown" if normalized_content.empty?

      match = finals.any? do |fa|
        value = fa["value"].to_s
        next false if value.blank?

        normalize(value).then do |nv|
          nv.length >= 2 && normalized_content.include?(nv)
        end
      end

      match ? "correct" : "unknown"
    end

    private

    def normalize(text)
      text.to_s
          .downcase
          .gsub(",", ".")            # decimal sep
          .gsub(UNITS_TO_STRIP, "")  # units
          .gsub(/\s+/, "")           # collapse spaces
          .strip
    end
  end
end
