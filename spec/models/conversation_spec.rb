# spec/models/conversation_spec.rb
require "rails_helper"

RSpec.describe Conversation, type: :model do
  describe "associations" do
    it "belongs to student" do
      conversation = build(:conversation)
      expect(conversation.student).to be_a(Student)
    end

    it "belongs to question" do
      conversation = build(:conversation)
      expect(conversation.question).to be_a(Question)
    end
  end

  describe "validations" do
    it "is valid with valid attributes" do
      conversation = build(:conversation)
      expect(conversation).to be_valid
    end

    it "is invalid without student" do
      conversation = build(:conversation, student: nil)
      expect(conversation).not_to be_valid
    end

    it "is invalid without question" do
      conversation = build(:conversation, question: nil)
      expect(conversation).not_to be_valid
    end
  end

  describe "#add_message!" do
    it "adds a message to the messages array" do
      conversation = create(:conversation, messages: [])
      conversation.add_message!(role: "user", content: "Bonjour")

      expect(conversation.messages.size).to eq(1)
      expect(conversation.messages.first["role"]).to eq("user")
      expect(conversation.messages.first["content"]).to eq("Bonjour")
      expect(conversation.messages.first["at"]).to be_present
    end

    it "appends to existing messages" do
      conversation = create(:conversation, messages: [ { "role" => "user", "content" => "Hello", "at" => Time.current.iso8601 } ])
      conversation.add_message!(role: "assistant", content: "Bonjour !")

      expect(conversation.messages.size).to eq(2)
    end
  end

  describe "#messages_for_api" do
    it "returns messages in API format" do
      conversation = build(:conversation, messages: [
        { "role" => "user", "content" => "Bonjour", "at" => "2026-01-01T00:00:00Z" },
        { "role" => "assistant", "content" => "Salut !", "at" => "2026-01-01T00:00:01Z" }
      ])

      result = conversation.messages_for_api
      expect(result).to eq([
        { role: "user", content: "Bonjour" },
        { role: "assistant", content: "Salut !" }
      ])
    end
  end
end
