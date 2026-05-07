require "rails_helper"

RSpec.describe Tutor::BroadcastDone do
  let(:student) { create(:student) }
  let(:subject_record) { create(:subject) }
  let(:question) { create(:question, part: create(:part, subject: subject_record), answer_type: "calcul") }
  let(:conversation) { create(:conversation, student: student, subject: subject_record) }
  let(:assistant_message) { create(:message, conversation: conversation, role: :assistant, content: "Salut.", question: question) }

  describe ".call" do
    it "broadcasts a done payload with message and chips_html" do
      expect(ActionCable.server).to receive(:broadcast).with(
        "conversation_#{conversation.id}",
        hash_including(type: "done", message: hash_including(id: assistant_message.id), chips_html: be_a(String))
      )

      result = described_class.call(
        conversation: conversation,
        message:      assistant_message,
        question:     question,
        access_code:  "tutor-sim"
      )
      expect(result.ok?).to be(true)
    end

    it "is resilient to chips render errors (returns ok with empty chips_html)" do
      allow(ApplicationController.renderer).to receive(:render).and_raise("render boom")
      expect(ActionCable.server).to receive(:broadcast).with(
        anything,
        hash_including(chips_html: "")
      )

      described_class.call(conversation: conversation, message: assistant_message,
                           question: question, access_code: "tutor-sim")
    end
  end
end
