# frozen_string_literal: true

class Message < ApplicationRecord
  belongs_to :conversation
  belongs_to :question, optional: true

  enum :role, { user: 0, assistant: 1, system: 2 }
  enum :kind, { normal: 0, welcome: 1, intro: 2 }

  validates :content, presence: true, unless: :streaming_assistant?

  private

  def streaming_assistant?
    assistant? && streaming_finished_at.nil?
  end
end
