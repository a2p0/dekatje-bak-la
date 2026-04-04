class Part < ApplicationRecord
  belongs_to :subject, optional: true
  belongs_to :exam_session, optional: true
  has_many :questions, dependent: :destroy

  enum :section_type, { common: 0, specific: 1 }
  enum :specialty, { SIN: 0, ITEC: 1, EE: 2, AC: 3 }, prefix: true

  validates :number, :title, presence: true
  validate :exactly_one_owner

  private

  def exactly_one_owner
    has_subject = subject_id.present? || subject.present?
    has_exam_session = exam_session_id.present? || exam_session.present?

    if has_subject && has_exam_session
      errors.add(:base, "must belong to either a subject or an exam_session, not both")
    elsif !has_subject && !has_exam_session
      errors.add(:base, "must belong to either a subject or an exam_session")
    end
  end
end
