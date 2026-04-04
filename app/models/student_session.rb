class StudentSession < ApplicationRecord
  belongs_to :student
  belongs_to :subject

  enum :mode, { autonomous: 0, tutored: 1 }
  enum :part_filter, { full: 0, common_only: 1, specific_only: 2 }

  validates :student_id, uniqueness: { scope: :subject_id }

  def mark_seen!(question_id)
    key = question_id.to_s
    progression[key] ||= {}
    progression[key]["seen"] = true
    update!(last_activity_at: Time.current)
  end

  def mark_answered!(question_id)
    key = question_id.to_s
    progression[key] ||= {}
    progression[key]["answered"] = true
    update!(last_activity_at: Time.current)
  end

  def answered?(question_id)
    progression.dig(question_id.to_s, "answered") == true
  end

  def answered_count
    progression.count { |_k, v| v["answered"] == true }
  end

  def first_undone_question(part)
    questions = part.questions.kept.order(:position)
    questions.detect { |q| !answered?(q.id) } || questions.first
  end

  # Tutor state helpers

  def question_step(question_id)
    tutor_state.dig("question_states", question_id.to_s, "step")
  end

  def set_question_step!(question_id, step)
    key = question_id.to_s
    states = tutor_state["question_states"] ||= {}
    states[key] ||= {}
    states[key]["step"] = step
    update!(tutor_state: tutor_state)
  end

  def store_spotting!(question_id, data)
    key = question_id.to_s
    states = tutor_state["question_states"] ||= {}
    states[key] ||= {}
    states[key]["spotting"] = data
    update!(tutor_state: tutor_state)
  end

  def spotting_data(question_id)
    tutor_state.dig("question_states", question_id.to_s, "spotting")
  end

  def spotting_completed?(question_id)
    %w[feedback skipped].include?(question_step(question_id))
  end

  def tutored_active?
    return false unless tutored?
    tutor_state.dig("question_states").present?
  end
end
