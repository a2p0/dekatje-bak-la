class Subject < ApplicationRecord
  belongs_to :owner, class_name: "User"
  belongs_to :exam_session, optional: true
  has_one :extraction_job, dependent: :destroy
  has_many :parts, dependent: :destroy
  has_many :classroom_subjects, dependent: :destroy
  has_many :classrooms, through: :classroom_subjects
  has_many :student_sessions, dependent: :destroy

  # New format: single consolidated PDFs
  has_one_attached :subject_pdf
  has_one_attached :correction_pdf

  # Legacy format: 5 separate files
  has_one_attached :enonce_file
  has_one_attached :dt_file
  has_one_attached :dr_vierge_file
  has_one_attached :dr_corrige_file
  has_one_attached :questions_corrigees_file

  enum :exam_type, { bac: 0, bts: 1, autre: 2 }
  enum :specialty, { tronc_commun: 0, SIN: 1, ITEC: 2, EE: 3, AC: 4 }
  enum :region,    { metropole: 0, drom_com: 1, polynesie: 2, candidat_libre: 3 }
  enum :status,    { draft: 0, pending_validation: 1, published: 2, archived: 3 }

  validates :title, :year, :exam_type, :specialty, :region, presence: true

  validate :required_files_attached

  scope :kept, -> { where(discarded_at: nil) }

  def new_format?
    subject_pdf.attached?
  end

  def effective_presentation_text
    exam_session&.presentation_text || presentation_text
  end

  def validated_questions_count
    parts.joins(:questions).merge(Question.where(status: :validated).kept).count
  end

  def publishable?
    validated_questions_count > 0
  end

  private

  def required_files_attached
    if subject_pdf.attached?
      errors.add(:correction_pdf, :blank) unless correction_pdf.attached?
    elsif enonce_file.attached?
      %i[enonce_file dt_file dr_vierge_file dr_corrige_file questions_corrigees_file].each do |file|
        errors.add(file, :blank) unless public_send(file).attached?
      end
    else
      errors.add(:base, "Au moins un format de fichier est requis (subject_pdf ou enonce_file)")
    end
  end
end
