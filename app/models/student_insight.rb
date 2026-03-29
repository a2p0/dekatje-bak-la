# app/models/student_insight.rb
class StudentInsight < ApplicationRecord
  belongs_to :student
  belongs_to :subject
  belongs_to :question, optional: true

  INSIGHT_TYPES = %w[mastered struggle misconception note].freeze

  validates :insight_type, inclusion: { in: INSIGHT_TYPES }
  validates :concept, presence: true
end
