class Student < ApplicationRecord
  belongs_to :classroom
  has_secure_password
  has_many :student_sessions, dependent: :destroy

  encrypts :api_key

  enum :api_provider, { openrouter: 0, anthropic: 1, openai: 2, google: 3 }
  enum :default_mode, { revision: 0, tutored: 1 }

  validates :first_name, :last_name, :username, presence: true
  validates :username, uniqueness: { scope: :classroom_id }

  AVAILABLE_MODELS = {
    "openrouter" => [
      { id: "qwen/qwen3-next-80b-a3b-instruct:free", label: "Qwen3 80B (gratuit)", cost: "🆓", note: "Lent, rate limit bas" },
      { id: "deepseek/deepseek-chat-v3-0324", label: "DeepSeek V3", cost: "$" },
      { id: "anthropic/claude-sonnet-4-5", label: "Claude Sonnet 4.5", cost: "$$" }
    ],
    "anthropic" => [
      { id: "claude-haiku-4-5-20251001", label: "Claude Haiku 4.5", cost: "$" },
      { id: "claude-sonnet-4-5-20250514", label: "Claude Sonnet 4.5", cost: "$$" }
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
