class Student < ApplicationRecord
  belongs_to :classroom
  has_secure_password
  has_many :student_sessions, dependent: :destroy

  enum :api_provider, { openrouter: 0, anthropic: 1, openai: 2, google: 3 }

  validates :first_name, :last_name, :username, presence: true
  validates :username, uniqueness: { scope: :classroom_id }
end
