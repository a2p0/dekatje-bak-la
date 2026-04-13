require "rails_helper"

RSpec.xdescribe TutorChannel, type: :channel do
  let(:student) { create(:student) }
  let(:question) { create(:question) }
  let(:conversation) { create(:conversation, student: student, question: question) }

  before do
    stub_connection current_student: student, current_user: nil
  end

  describe "#subscribed" do
    it "subscribes to the conversation stream" do
      subscribe(conversation_id: conversation.id)

      expect(subscription).to be_confirmed
      expect(subscription).to have_stream_from("conversation_#{conversation.id}")
    end

    it "rejects subscription for another student's conversation" do
      other_student = create(:student)
      other_conversation = create(:conversation, student: other_student, question: question)

      subscribe(conversation_id: other_conversation.id)

      expect(subscription).to be_rejected
    end

    it "rejects subscription for non-existent conversation" do
      subscribe(conversation_id: 999999)

      expect(subscription).to be_rejected
    end
  end
end
