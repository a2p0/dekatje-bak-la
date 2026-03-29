# app/models/conversation.rb
class Conversation < ApplicationRecord
  belongs_to :student
  belongs_to :question

  # belongs_to already validates presence by default in Rails 5+

  def add_message!(role:, content:)
    messages << { "role" => role, "content" => content, "at" => Time.current.iso8601 }
    save!
  end

  def messages_for_api
    messages.map { |m| { role: m["role"], content: m["content"] } }
  end
end
