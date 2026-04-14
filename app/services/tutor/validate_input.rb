module Tutor
  class ValidateInput
    BLOCKLIST = %w[
      <|endoftext|>
      [INST]
      </s>
      <|im_start|>
      <|im_end|>
      [/INST]
      <<SYS>>
      <</SYS>>
    ].freeze

    def self.call(raw_input:)
      new(raw_input: raw_input).call
    end

    def initialize(raw_input:)
      @raw_input = raw_input
    end

    def call
      sanitized = @raw_input.to_s.strip
      BLOCKLIST.each { |token| sanitized = sanitized.gsub(token, "") }
      sanitized.strip!

      return Result.err("Input vide") if sanitized.empty?

      Result.ok(sanitized_input: "<student_input>#{sanitized}</student_input>")
    end
  end
end
