module Tutor
  class ApplyToolCalls
    ALLOWED_PHASES = %w[
      idle greeting enonce spotting_type spotting_data guiding validating feedback ended
    ].freeze

    TRANSITION_MATRIX = {
      "idle"          => %w[greeting],
      "greeting"      => %w[enonce],
      "enonce"        => %w[spotting_type guiding],
      "spotting_type" => %w[spotting_data guiding],
      "spotting_data" => %w[guiding],
      "guiding"       => %w[validating enonce],
      "validating"    => %w[feedback ended],
      "feedback"      => %w[ended]
    }.freeze

    QUESTION_REQUIRED_PHASES = %w[enonce spotting_type spotting_data guiding validating feedback ended].freeze
    MAX_HINTS = 5

    def self.call(conversation:, tool_calls:)
      new(conversation: conversation, tool_calls: tool_calls).call
    end

    def initialize(conversation:, tool_calls:)
      @conversation = conversation
      @tool_calls   = tool_calls
      @state        = conversation.tutor_state
    end

    def call
      @tool_calls.each do |tc|
        result = apply_one(tc[:name], tc[:args] || {})
        if result.err?
          Rails.logger.warn("[Tutor::ApplyToolCalls] ignored invalid tool call #{tc[:name].inspect}: #{result.error}")
          next
        end
        @state = result.value[:updated_tutor_state]
      end
      Result.ok(updated_tutor_state: @state)
    end

    private

    def apply_one(name, args)
      case name
      when "transition"           then apply_transition(args)
      when "update_learner_model" then apply_update_learner_model(args)
      when "request_hint"         then apply_request_hint(args)
      when "evaluate_spotting"    then apply_evaluate_spotting(args)
      else
        Result.ok(updated_tutor_state: @state)
      end
    end

    def apply_transition(args)
      target_phase = args["phase"].to_s
      question_id  = args["question_id"]

      unless ALLOWED_PHASES.include?(target_phase)
        return Result.err("transition: phase inconnue '#{target_phase}'")
      end

      allowed_targets = TRANSITION_MATRIX[@state.current_phase] || []
      unless allowed_targets.include?(target_phase)
        return Result.err(
          "transition: passage de '#{@state.current_phase}' vers '#{target_phase}' interdit"
        )
      end

      if QUESTION_REQUIRED_PHASES.include?(target_phase) && question_id.blank?
        return Result.err("transition: question_id requis pour la phase '#{target_phase}'")
      end

      new_state = @state.with(
        current_phase:       target_phase,
        current_question_id: question_id || @state.current_question_id
      )

      if question_id.present?
        qid_str = question_id.to_s
        existing_qs = new_state.question_states[qid_str] || QuestionState.new(
          phase: "enonce", step: nil, hints_used: 0, last_confidence: nil,
          error_types: [], completed_at: nil, intro_seen: false
        )
        updated_qs  = existing_qs.with(phase: target_phase)
        new_state   = new_state.with(
          question_states: new_state.question_states.merge(qid_str => updated_qs)
        )
      end

      Result.ok(updated_tutor_state: new_state)
    end

    def apply_update_learner_model(args)
      mastered  = args["concept_mastered"]
      to_revise = args["concept_to_revise"]
      delta     = args["discouragement_delta"].to_i

      new_mastered  = mastered  ? (@state.concepts_mastered  + [ mastered ]).uniq  : @state.concepts_mastered
      new_to_revise = to_revise ? (@state.concepts_to_revise + [ to_revise ]).uniq : @state.concepts_to_revise
      new_level     = [ [ @state.discouragement_level + delta, 0 ].max, 3 ].min

      new_state = @state.with(
        concepts_mastered:    new_mastered,
        concepts_to_revise:   new_to_revise,
        discouragement_level: new_level
      )
      Result.ok(updated_tutor_state: new_state)
    end

    def apply_request_hint(args)
      level = args["level"].to_i
      qid   = @state.current_question_id.to_s

      if qid.blank?
        return Result.err("request_hint: aucune question courante")
      end

      qs = @state.question_states[qid] || QuestionState.new(
        phase: "enonce", step: "initial", hints_used: 0, last_confidence: nil,
        error_types: [], completed_at: nil, intro_seen: false
      )

      if level > MAX_HINTS
        return Result.err("request_hint: niveau d'indice #{level} dépasse le maximum (#{MAX_HINTS})")
      end

      expected = qs.hints_used + 1
      if level != expected
        return Result.err(
          "request_hint: indice #{level} demandé mais #{expected} attendu (progression monotone requise)"
        )
      end

      new_qs       = qs.with(hints_used: level)
      new_q_states = @state.question_states.merge(qid => new_qs)
      new_state    = @state.with(question_states: new_q_states)

      Result.ok(updated_tutor_state: new_state)
    end

    def apply_evaluate_spotting(args)
      unless %w[spotting_type spotting_data].include?(@state.current_phase)
        return Result.err(
          "evaluate_spotting: disponible uniquement en phase spotting_type ou spotting_data (phase courante : #{@state.current_phase})"
        )
      end

      outcome = args["outcome"].to_s
      working_state = @state

      if %w[success forced_reveal].include?(outcome)
        transition_result = apply_transition(
          "phase"       => "guiding",
          "question_id" => @state.current_question_id
        )
        return transition_result if transition_result.err?

        working_state = transition_result.value[:updated_tutor_state]
      end

      Result.ok(updated_tutor_state: working_state)
    end
  end
end
