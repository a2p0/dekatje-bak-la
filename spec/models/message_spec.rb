# frozen_string_literal: true

require "rails_helper"

RSpec.describe Message, type: :model do
  describe "associations" do
    it "belongs_to :conversation" do
      reflection = described_class.reflect_on_association(:conversation)
      expect(reflection.macro).to eq(:belongs_to)
      expect(reflection.options[:optional]).to be_falsey
    end

    it "belongs_to :question as optional" do
      reflection = described_class.reflect_on_association(:question)
      expect(reflection.macro).to eq(:belongs_to)
      expect(reflection.options[:optional]).to eq(true)
    end
  end

  describe "validations" do
    it "requires content" do
      message = build(:message, content: nil)
      expect(message).not_to be_valid
      expect(message.errors[:content]).to include(a_string_matching(/blank|can't/i))
    end
  end

  describe "enums" do
    it "defines role enum with user=0, assistant=1, system=2" do
      expect(Message.roles).to eq({ "user" => 0, "assistant" => 1, "system" => 2 })
    end

    describe "kind (044)" do
      it "defines kind with normal=0, welcome=1, intro=2" do
        expect(Message.kinds).to eq({ "normal" => 0, "welcome" => 1, "intro" => 2 })
      end

      it "defaults to :normal kind" do
        expect(build(:message).kind).to eq("normal")
      end

      it "accepts :welcome kind" do
        expect(build(:message, kind: :welcome).kind).to eq("welcome")
      end

      it "accepts :intro kind" do
        expect(build(:message, kind: :intro).kind).to eq("intro")
      end
    end
  end

  describe "factory" do
    it "builds a valid message" do
      expect(build(:message)).to be_valid
    end

    it "defaults to user role" do
      expect(build(:message).role).to eq("user")
    end

    it "can build an assistant message" do
      msg = build(:message, role: :assistant)
      expect(msg.role).to eq("assistant")
    end

    it "can build a message with a question" do
      question = create(:question)
      msg = build(:message, question: question)
      expect(msg.question).to eq(question)
    end
  end

  describe "chunk_index default" do
    it "persists with chunk_index 0 by default" do
      msg = create(:message)
      expect(msg.chunk_index).to eq(0)
    end
  end
end
