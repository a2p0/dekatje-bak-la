class ExamSession < ApplicationRecord
  belongs_to :owner, class_name: "User"
  has_many :subjects, dependent: :restrict_with_error
  has_many :common_parts, -> { where(section_type: :common) }, class_name: "Part", foreign_key: :exam_session_id, dependent: :destroy

  enum :region, { metropole: 0, reunion: 1, polynesie: 2, candidat_libre: 3 }
  enum :exam, { bac: 0, bts: 1, autre: 2 }
  enum :variante, { normale: 0, remplacement: 1 }

  validates :title, :year, :region, :exam, presence: true
end
