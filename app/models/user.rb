class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  enum :api_provider, { anthropic: 0, openrouter: 1, openai: 2, google: 3 }

  validates :first_name, :last_name, presence: true
end
