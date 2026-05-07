class TutorStateType < ActiveRecord::Type::Json
  def deserialize(value)
    raw = value.is_a?(String) ? super(value) : value
    raw = {} if raw.blank?
    raw = {} unless raw.is_a?(Hash)

    TutorState.new(
      current_question_id: raw["current_question_id"],
      greeted:             raw["greeted"] == true,
      question_traces:     deserialize_traces(raw["question_traces"]),
      concepts_seen:       Array(raw["concepts_seen"]).map(&:to_s).freeze
    )
  end

  def serialize(value)
    return super({}) if value.nil?
    raise ArgumentError, "expected TutorState, got #{value.class}" unless value.is_a?(TutorState)

    super(
      "current_question_id" => value.current_question_id,
      "greeted"             => value.greeted,
      "question_traces"     => value.question_traces.transform_values { |t| serialize_trace(t) },
      "concepts_seen"       => value.concepts_seen
    )
  end

  private

  def deserialize_traces(raw)
    return {}.freeze unless raw.is_a?(Hash)

    raw.each_with_object({}) do |(qid, payload), acc|
      events = Array(payload["events"]).map(&:dup)
      acc[qid.to_s] = QuestionTrace.new(
        question_id: payload["question_id"]&.to_i || qid.to_i,
        events:      events.freeze
      )
    end.freeze
  end

  def serialize_trace(trace)
    {
      "question_id" => trace.question_id,
      "events"      => trace.events
    }
  end
end
