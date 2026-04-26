module Tutor
  class ProcessMessage
    def self.call(conversation:, student_input:, question:)
      new(conversation: conversation, student_input: student_input, question: question).call
    end

    def initialize(conversation:, student_input:, question:)
      @conversation  = conversation
      @student_input = student_input
      @question      = question
    end

    def call
      validate_result = ValidateInput.call(raw_input: @student_input)
      return validate_result if validate_result.err?

      sanitized = validate_result.value[:sanitized_input]

      context_result = BuildContext.call(
        conversation:  @conversation,
        question:      @question,
        student_input: sanitized
      )
      return context_result if context_result.err?

      @conversation.messages.create!(
        role:     :user,
        content:  sanitized,
        question: @question
      )

      assistant_msg = @conversation.messages.create!(
        role:        :assistant,
        content:     "",
        question:    @question,
        chunk_index: 0
      )

      llm_result = CallLlm.call(
        conversation:    @conversation,
        system_prompt:   context_result.value[:system_prompt],
        messages:        context_result.value[:messages],
        student_message: assistant_msg
      )
      return llm_result if llm_result.err?

      if %w[spotting_type spotting_data].include?(@conversation.tutor_state.current_phase)
        filter_result = FilterSpottingOutput.call(
          message:    assistant_msg,
          llm_output: llm_result.value[:full_content]
        )
        return filter_result if filter_result.err?
      end

      parse_result = ParseToolCalls.call(tool_calls: llm_result.value[:tool_calls])
      return parse_result if parse_result.err?

      apply_result = ApplyToolCalls.call(
        conversation: @conversation,
        tool_calls:   parse_result.value[:parsed]
      )
      return apply_result if apply_result.err?

      spotting_tool = parse_result.value[:parsed].find { |t| t[:name] == "evaluate_spotting" }
      if spotting_tool
        InjectDataHints.call(
          conversation: @conversation,
          question:     @question,
          outcome:      spotting_tool[:args]["outcome"].to_s
        )
      end

      update_result = UpdateTutorState.call(
        conversation: @conversation,
        tutor_state:  apply_result.value[:updated_tutor_state]
      )
      return update_result if update_result.err?

      BroadcastMessage.call(conversation: @conversation, message: assistant_msg)
    end
  end
end
