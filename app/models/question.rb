class Question < ApplicationRecord
  class InvalidTransition < StandardError; end

  belongs_to :part
  has_one :answer, dependent: :destroy
  has_many :messages, dependent: :nullify

  enum :answer_type, {
    identification: 0,
    calcul:         1,
    justification:  2,
    representation: 3,
    qcm:            4,
    verification:   5,
    conclusion:     6
  }
  enum :status, { draft: 0, validated: 1 }

  validates :number, :label, presence: true

  scope :kept, -> { where(discarded_at: nil) }
  scope :for_parts, ->(parts) { kept.where(part: parts) }
  scope :for_subject, ->(subject) { kept.joins(:part).where(parts: { subject_id: subject.id }) }

  def validate!
    raise InvalidTransition, "Cette question est déjà validée." if validated?

    update!(status: :validated)
  end

  def invalidate!
    raise InvalidTransition, "Cette question est déjà en brouillon." if draft?

    update!(status: :draft)
  end
end
