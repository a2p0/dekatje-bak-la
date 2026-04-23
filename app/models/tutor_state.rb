# app/models/tutor_state.rb

QuestionState = Data.define(
  :step,             # Integer — current tutoring step for this question
  :hints_used,       # Integer 0-5
  :last_confidence,  # Integer 1-5, or nil
  :error_types,      # Array<String>
  :completed_at,     # String ISO8601 or nil
  :intro_seen        # Boolean — true once drawer opened for this question (044)
)

TutorState = Data.define(
  :current_phase,        # String — e.g. "idle", "spotting", "chat"
  :current_question_id,  # Integer or nil
  :concepts_mastered,    # Array<String>
  :concepts_to_revise,   # Array<String>
  :discouragement_level, # Integer 0-3
  :question_states,      # Hash<String, QuestionState>
  :welcome_sent          # Boolean — true once welcome message sent for this subject (044)
) do
  def self.default
    new(
      current_phase:        "idle",
      current_question_id:  nil,
      concepts_mastered:    [].freeze,
      concepts_to_revise:   [].freeze,
      discouragement_level: 0,
      question_states:      {}.freeze,
      welcome_sent:         false
    )
  end

  def to_prompt
    lines = []
    lines << "L'élève travaille sur la question #{current_question_id}." if current_question_id
    lines << "Phase courante : #{current_phase}."
    lines << "Concepts maîtrisés : #{concepts_mastered.join(', ')}." if concepts_mastered.any?
    lines << "Points à revoir : #{concepts_to_revise.join(', ')}." if concepts_to_revise.any?
    lines << "Niveau de découragement : #{discouragement_level}/3."
    if (qs = question_states[current_question_id.to_s])
      lines << "Indices utilisés sur cette question : #{qs.hints_used}/5."
      lines << "Dernière confiance déclarée : #{qs.last_confidence}/5." if qs.last_confidence
    end
    lines.join("\n")
  end
end
