class ClassroomSubject < ApplicationRecord
  belongs_to :classroom
  belongs_to :subject

  validates :classroom_id, uniqueness: { scope: :subject_id }
end
