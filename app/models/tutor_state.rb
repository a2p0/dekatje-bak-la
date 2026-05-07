# 062: TutorState root and QuestionTrace per-question.
# - Pas de champ phase persisté (la phase est dérivée par Tutor::DerivePhase).
# - QuestionTrace.events est append-only; budget est calculé à la volée.

QuestionTrace = Data.define(:question_id, :events) do
  def self.empty(question_id:)
    new(question_id: question_id, events: [].freeze)
  end

  def append(event)
    with(events: events + [ event ].freeze)
  end

  def budget
    {
      formule_given:     event_present?("tutor_gave", "what" => "formule"),
      value_given:       event_present?("tutor_gave", "what" => "valeur"),
      calc_given:        event_present?("tutor_gave", "what" => "calcul"),
      result_given:      event_present?("tutor_gave", "what" => "résultat"),
      attempts_count:    events.count { |e| e["type"] == "student_attempt" },
      viewed_correction: event_present?("viewed_correction")
    }
  end

  def cap_active?
    !budget[:viewed_correction] && budget[:attempts_count] < 2
  end

  def last_signal
    events.last
  end

  private

  def event_present?(type, match = {})
    events.any? do |e|
      e["type"] == type && match.all? { |k, v| e[k.to_s] == v }
    end
  end
end

TutorState = Data.define(
  :current_question_id,
  :greeted,
  :question_traces,
  :concepts_seen
) do
  def self.default
    new(
      current_question_id: nil,
      greeted:             false,
      question_traces:     {}.freeze,
      concepts_seen:       [].freeze
    )
  end

  def trace_for(question_id)
    question_traces[question_id.to_s] || QuestionTrace.empty(question_id: question_id)
  end

  def with_trace(trace)
    new_traces = question_traces.merge(trace.question_id.to_s => trace).freeze
    with(question_traces: new_traces)
  end

  def with_concept(concept)
    return self if concept.blank? || concepts_seen.include?(concept)
    with(concepts_seen: (concepts_seen + [ concept ]).freeze)
  end
end
