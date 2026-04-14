module Tutor
  class FilterSpottingOutput
    NEUTRAL_RELAUNCH = "Reformule ta réponse sans mentionner de documents spécifiques ni de valeurs chiffrées. Où penses-tu trouver les informations ?".freeze

    FORBIDDEN_PATTERNS = [
      /\bD[TR]\s*\d+\b/i,
      /\d+[,.]?\d*\s*(km|l|kWh|W|N|kg|m|s|h|min|%|€|°C)\b/i
    ].freeze

    def self.call(message:, llm_output:)
      new(message: message, llm_output: llm_output).call
    end

    def initialize(message:, llm_output:)
      @message    = message
      @llm_output = llm_output
    end

    def call
      return Result.ok(filtered: false) unless in_spotting_phase?

      if forbidden?
        @message.update!(content: NEUTRAL_RELAUNCH)
        Result.ok(filtered: true)
      else
        @message.update!(content: @llm_output)
        Result.ok(filtered: false)
      end
    end

    private

    def in_spotting_phase?
      @message.conversation.tutor_state.current_phase == "spotting"
    end

    def forbidden?
      FORBIDDEN_PATTERNS.any? { |pattern| @llm_output.match?(pattern) }
    end
  end
end
