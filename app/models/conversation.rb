class Conversation < ApplicationRecord
  include AASM

  belongs_to :student
  belongs_to :subject
  has_many :messages, dependent: :destroy

  validates :student_id, uniqueness: { scope: :subject_id }

  attribute :tutor_state, TutorStateType.new

  aasm column: :lifecycle_state do
    state :disabled, initial: true
    state :active
    state :validating
    state :feedback
    state :done

    event :activate do
      transitions from: :disabled, to: :active,
                  guard: :student_has_api_key_or_free_mode?
    end

    event :request_validation do
      transitions from: :active, to: :validating
    end

    event :give_feedback do
      transitions from: :validating, to: :feedback
    end

    event :resume do
      transitions from: :feedback, to: :active
    end

    event :finish do
      transitions from: [ :active, :feedback ], to: :done
    end
  end

  private

  def student_has_api_key_or_free_mode?
    student.api_key.present? ||
      student.classroom&.tutor_free_mode_enabled?
  end
end
