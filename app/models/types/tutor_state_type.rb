# app/models/types/tutor_state_type.rb
class TutorStateType < ActiveRecord::Type::Json
  def cast(value)
    case value
    when TutorState
      value
    when Hash
      cast_from_hash(value)
    when NilClass
      TutorState.default
    else
      raise ArgumentError, "Cannot cast #{value.class} to TutorState"
    end
  end

  def serialize(value)
    return super({}) if value.nil?

    tutor_state = cast(value)
    super(
      "current_phase"        => tutor_state.current_phase,
      "current_question_id"  => tutor_state.current_question_id,
      "concepts_mastered"    => tutor_state.concepts_mastered,
      "concepts_to_revise"   => tutor_state.concepts_to_revise,
      "discouragement_level" => tutor_state.discouragement_level,
      "question_states"      => serialize_question_states(tutor_state.question_states),
      "welcome_sent"         => tutor_state.welcome_sent,
      "last_activity_at"     => tutor_state.last_activity_at
    )
  end

  def deserialize(value)
    return TutorState.default if value.nil?

    parsed = value.is_a?(String) ? JSON.parse(value) : value
    cast(parsed)
  end

  private

  def cast_from_hash(hash)
    raw_states = hash["question_states"] || {}
    question_states = raw_states.transform_values do |qs_hash|
      next qs_hash if qs_hash.is_a?(QuestionState)

      raw_phase = qs_hash["phase"]
      phase = VALID_QUESTION_PHASES.include?(raw_phase) ? raw_phase : "enonce"

      QuestionState.new(
        phase:            phase,
        step:             qs_hash["step"],
        hints_used:       qs_hash["hints_used"] || 0,
        last_confidence:  qs_hash["last_confidence"],
        error_types:      Array(qs_hash["error_types"]),
        completed_at:     qs_hash["completed_at"],
        intro_seen:       qs_hash["intro_seen"] || false
      )
    end

    TutorState.new(
      current_phase:        hash["current_phase"] || "idle",
      current_question_id:  hash["current_question_id"],
      concepts_mastered:    Array(hash["concepts_mastered"]),
      concepts_to_revise:   Array(hash["concepts_to_revise"]),
      discouragement_level: hash["discouragement_level"] || 0,
      question_states:      question_states,
      welcome_sent:         hash["welcome_sent"] || false,
      last_activity_at:     hash["last_activity_at"]
    )
  end

  def serialize_question_states(question_states)
    question_states.transform_values do |qs|
      {
        "phase"           => qs.phase,
        "step"            => qs.step,
        "hints_used"      => qs.hints_used,
        "last_confidence" => qs.last_confidence,
        "error_types"     => qs.error_types,
        "completed_at"    => qs.completed_at,
        "intro_seen"      => qs.intro_seen
      }
    end
  end
end
