require "rails_helper"

RSpec.describe Tutor::BroadcastMessage do
  let(:user)         { create(:user) }
  let(:classroom)    { create(:classroom, owner: user) }
  let(:student)      { create(:student, classroom: classroom) }
  let(:exam_subject) { create(:subject, owner: user, status: :published) }
  let(:conversation) { create(:conversation, student: student, subject: exam_subject) }
  let(:part)         { create(:part, subject: exam_subject) }
  let(:question)     { create(:question, part: part) }
  let(:message) do
    create(:message,
           conversation: conversation,
           role:         :assistant,
           content:      "Qu'est-ce que tu as essayé ?",
           chunk_index:  0)
  end

  it "broadcasts a typed done envelope to the conversation channel and returns ok" do
    expect(ActionCable.server).to receive(:broadcast).with(
      "conversation_#{conversation.id}",
      hash_including(
        type:    "done",
        message: hash_including(content: message.content)
      )
    )
    result = described_class.call(conversation: conversation, message: message)
    expect(result.ok?).to be true
  end
end
