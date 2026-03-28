class Classroom < ApplicationRecord
  belongs_to :owner, class_name: "User"
  has_many :students, dependent: :destroy
  has_many :classroom_subjects, dependent: :destroy
  has_many :subjects, through: :classroom_subjects

  validates :name, :school_year, :access_code, presence: true
  validates :access_code, uniqueness: true
end
