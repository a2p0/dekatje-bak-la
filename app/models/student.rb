class Student < ApplicationRecord
  belongs_to :classroom
  has_secure_password
  has_many :student_sessions, dependent: :destroy
  has_many :conversations, dependent: :destroy
  has_many :student_insights, dependent: :destroy

  encrypts :api_key

  enum :api_provider, { openrouter: 0, anthropic: 1, openai: 2, google: 3 }
  enum :default_mode, { revision: 0, tutored: 1 }
  enum :specialty, { SIN: 0, ITEC: 1, EE: 2, AC: 3 }, prefix: true

  validates :first_name, :last_name, :username, presence: true
  validates :username, uniqueness: { scope: :classroom_id }

  AVAILABLE_MODELS = {
    "openrouter" => [
      { id: "mistralai/mistral-small-2603", label: "Mistral Small 4", cost: "$", note: "Recommandé" },
      { id: "google/gemini-2.0-flash-001", label: "Gemini 2.0 Flash", cost: "$" },
      { id: "anthropic/claude-haiku-4-5", label: "Claude Haiku 4.5", cost: "$$" },
      { id: "anthropic/claude-sonnet-4-6", label: "Claude Sonnet 4.6", cost: "$$$" }
    ],
    "anthropic" => [
      { id: "claude-haiku-4-5-20251001", label: "Claude Haiku 4.5", cost: "$" },
      { id: "claude-sonnet-4-6", label: "Claude Sonnet 4.6", cost: "$$" }
    ],
    "openai" => [
      { id: "gpt-4o-mini", label: "GPT-4o Mini", cost: "$" },
      { id: "gpt-4o", label: "GPT-4o", cost: "$$" }
    ],
    "google" => [
      { id: "gemini-2.0-flash", label: "Gemini 2.0 Flash", cost: "$" },
      { id: "gemini-2.5-pro-preview-06-05", label: "Gemini 2.5 Pro", cost: "$$$" }
    ]
  }.freeze

  def default_model_for_provider
    AVAILABLE_MODELS[api_provider]&.first&.dig(:id)
  end

  def effective_model
    api_model.presence || default_model_for_provider
  end
end
