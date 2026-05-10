module Tutor
  # 062 orchestrator. One LLM call per turn (streaming), then inline classify
  # post-response, record events, broadcast done.
  #
  # Flow:
  #   ValidateInput → RecordEvent(student_attempt) → BuildContext → CallLlm
  #   → Classify → RecordEvent(tutor_gave / concept_seen / cap_violation)
  #   → BroadcastDone
  class ProcessMessage
    def self.call(conversation:, student_input:, question:, access_code:)
      new(conversation: conversation, student_input: student_input,
          question: question, access_code: access_code).call
    end

    def initialize(conversation:, student_input:, question:, access_code:)
      @conversation  = conversation
      @student_input = student_input
      @question      = question
      @access_code   = access_code
    end

    def call
      validate_result = ValidateInput.call(raw_input: @student_input)
      return validate_result if validate_result.err?

      sanitized_for_llm = validate_result.value[:sanitized_input]
      display_content   = @student_input.to_s.strip

      last_signal = detect_last_signal(display_content)

      # Option C: always record student_attempt — the message is an attempt even
      # on the very first turn. :fresh_open still flows to BuildContext to shape
      # the greeting behavior but must not block trace recording.
      #
      # Verdict is computed deterministically by ClassifyAttempt against the
      # question's structured_correction.final_answers. Returns "correct" if a
      # final answer value is found in the student content (after normalization),
      # else "unknown". MVP: no LLM call, no numeric tolerance.
      verdict = ClassifyAttempt.call(student_content: display_content, question: @question)

      RecordEvent.call(
        conversation: @conversation,
        question_id:  @question.id,
        type:         "student_attempt",
        source:       "llm_message",
        content:      display_content,
        verdict:      verdict
      )

      @conversation.messages.create!(role: :user, content: display_content, question: @question)
      assistant_msg = @conversation.messages.create!(
        role: :assistant, content: "", question: @question, chunk_index: 0
      )

      # Note: user/assistant messages are persisted before BuildContext can fail.
      # If BuildContext returns Result.err the empty assistant message stays in
      # the DB. Acceptable for the MVP (BuildContext only fails if the question
      # has no part, which we treat as a developer error). Future cleanup: T18
      # legacy-cleanup pass.
      context_result = BuildContext.call(
        conversation:  @conversation.reload,
        question:      @question,
        student_input: sanitized_for_llm,
        last_signal:   last_signal
      )
      return context_result if context_result.err?

      llm_result = CallLlm.call(
        conversation:    @conversation,
        system_prompt:   context_result.value[:system_prompt],
        messages:        context_result.value[:messages],
        student_message: assistant_msg
      )
      return llm_result if llm_result.err?

      tutor_text = llm_result.value[:full_content]

      classify_result = Classify.call(tutor_message: tutor_text, answer_type: @question.answer_type.to_s)
      annotation = classify_result.value[:annotation]

      record_tutor_events(annotation)
      mark_greeted_if_needed

      BroadcastDone.call(
        conversation: @conversation.reload,
        message:      assistant_msg,
        question:     @question,
        access_code:  @access_code
      )
    end

    private

    def detect_last_signal(content)
      return :fresh_open if @conversation.tutor_state.greeted == false

      return :chip_formule  if content.include?("Quelle formule")
      return :chip_valeur   if content.include?("Où je trouve les données")
      return :chip_calcul   if content.match?(/refaire le calcul ensemble/)
      return :chip_resultat if content.match?(/résultat final/i)

      :dont_understand
    end

    def record_tutor_events(annotation)
      cap_active = @conversation.tutor_state.trace_for(@question.id).cap_active?

      record_what("formule",  "gives_formula",     annotation)
      record_what("valeur",   "gives_value",       annotation)
      record_what("calcul",   "gives_calculation", annotation)

      if annotation["gives_result"]
        if cap_active
          RecordEvent.call(
            conversation: @conversation,
            question_id:  @question.id,
            type:         "cap_violation",
            source:       "classifier"
          )
        else
          RecordEvent.call(
            conversation: @conversation,
            question_id:  @question.id,
            type:         "tutor_gave",
            source:       "classifier",
            what:         "résultat"
          )
        end
      end

      Array(annotation["concepts"]).each do |c|
        next if c.blank?
        RecordEvent.call(
          conversation: @conversation,
          question_id:  @question.id,
          type:         "concept_seen",
          source:       "classifier",
          concept:      c
        )
      end
    end

    def record_what(what, key, annotation)
      return unless annotation[key]
      RecordEvent.call(
        conversation: @conversation,
        question_id:  @question.id,
        type:         "tutor_gave",
        source:       "classifier",
        what:         what
      )
    end

    def mark_greeted_if_needed
      # Use a lock to read the freshest tutor_state (RecordEvent may have just
      # written new events via its own Conversation.lock.find). A plain
      # @conversation.tutor_state.with(greeted: true) would overwrite those events.
      Conversation.transaction do
        conv = Conversation.lock.find(@conversation.id)
        next if conv.tutor_state.greeted

        conv.update!(tutor_state: conv.tutor_state.with(greeted: true))
      end
    end
  end
end
