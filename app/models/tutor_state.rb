# app/models/tutor_state.rb

QuestionState = Data.define(
  :step,             # Integer — current tutoring step for this question
  :hints_used,       # Integer 0-5
  :last_confidence,  # Integer 1-5, or nil
  :error_types,      # Array<String>
  :completed_at      # String ISO8601 or nil
)

TutorState = Data.define(
  :current_phase,        # String — e.g. "idle", "spotting", "chat"
  :current_question_id,  # Integer or nil
  :concepts_mastered,    # Array<String>
  :concepts_to_revise,   # Array<String>
  :discouragement_level, # Integer 0-3
  :question_states       # Hash<String, QuestionState>
) do
  def self.default
    new(
      current_phase:        "idle",
      current_question_id:  nil,
      concepts_mastered:    [].freeze,
      concepts_to_revise:   [].freeze,
      discouragement_level: 0,
      question_states:      {}.freeze
    )
  end
end
