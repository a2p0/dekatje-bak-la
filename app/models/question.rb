class Question < ApplicationRecord
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
end
