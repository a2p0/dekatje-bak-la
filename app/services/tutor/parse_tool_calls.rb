module Tutor
  class ParseToolCalls
    def self.call(tool_calls:)
      new(tool_calls: tool_calls).call
    end

    def initialize(tool_calls:)
      @tool_calls = tool_calls
    end

    def call
      parsed = @tool_calls.map do |tc|
        {
          name: tc.name.to_s,
          args: tc.arguments.is_a?(Hash) ? tc.arguments : {}
        }
      end
      Result.ok(parsed: parsed)
    end
  end
end
