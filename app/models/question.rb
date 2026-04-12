class Question < ApplicationRecord
  class InvalidTransition < StandardError; end

  belongs_to :part
  has_one :answer, dependent: :destroy
  has_many :conversations, dependent: :destroy

  enum :answer_type, {
    text: 0, calculation: 1, argumentation: 2,
    dr_reference: 3, completion: 4, choice: 5
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
