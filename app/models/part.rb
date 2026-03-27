class Part < ApplicationRecord
  belongs_to :subject
  has_many :questions, dependent: :destroy

  enum :section_type, { common: 0, specific: 1 }

  validates :number, :title, presence: true
end
