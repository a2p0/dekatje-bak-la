class Subject < ApplicationRecord
  belongs_to :owner, class_name: "User"
  has_one :extraction_job, dependent: :destroy
  has_many :parts, dependent: :destroy

  has_one_attached :enonce_file
  has_one_attached :dt_file
  has_one_attached :dr_vierge_file
  has_one_attached :dr_corrige_file
  has_one_attached :questions_corrigees_file

  enum :exam_type, { bac: 0, bts: 1, autre: 2 }
  enum :specialty, { tronc_commun: 0, SIN: 1, ITEC: 2, EC: 3, AC: 4 }
  enum :region,    { metropole: 0, drom_com: 1, polynesie: 2, candidat_libre: 3 }
  enum :status,    { draft: 0, pending_validation: 1, published: 2, archived: 3 }

  validates :title, :year, :exam_type, :specialty, :region, presence: true

  validate :all_files_attached

  scope :kept, -> { where(discarded_at: nil) }

  private

  def all_files_attached
    %i[enonce_file dt_file dr_vierge_file dr_corrige_file questions_corrigees_file].each do |file|
      errors.add(file, :blank) unless public_send(file).attached?
    end
  end
end
