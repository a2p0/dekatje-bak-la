class StudentSession < ApplicationRecord
  belongs_to :student
  belongs_to :subject

  enum :mode, { autonomous: 0, tutored: 1 }

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

  def first_undone_question(part)
    questions = part.questions.kept.order(:position)
    questions.detect { |q| !answered?(q.id) } || questions.first
  end
end
