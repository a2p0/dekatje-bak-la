# frozen_string_literal: true

class Message < ApplicationRecord
  belongs_to :conversation
  belongs_to :question, optional: true

  enum :role, { user: 0, assistant: 1, system: 2 }

  validates :content, presence: true
end
