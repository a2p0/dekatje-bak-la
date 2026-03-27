class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :confirmable

  enum :api_provider, { anthropic: 0, openrouter: 1, openai: 2, google: 3 }

  has_many :classrooms, foreign_key: :owner_id, dependent: :destroy
  has_many :subjects, foreign_key: :owner_id, dependent: :destroy

  validates :first_name, :last_name, presence: true
end
