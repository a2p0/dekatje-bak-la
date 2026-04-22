require "rails_helper"

RSpec.describe ConversationChannel, type: :channel do
  let(:user)         { create(:user) }
  let(:classroom)    { create(:classroom, owner: user) }
  let(:student)      { create(:student, classroom: classroom) }
  let(:exam_subject) { create(:subject, owner: user, status: :published) }
  let(:conversation) do
    create(:conversation, student: student, subject: exam_subject,
           lifecycle_state: "active", tutor_state: TutorState.default)
  end

  before do
    stub_connection current_student: student
  end

  it "subscribes successfully for the owning student" do
    subscribe(conversation_id: conversation.id)
    expect(subscription).to be_confirmed
    expect(subscription).to have_stream_from("conversation_#{conversation.id}")
  end

  it "rejects subscription when conversation does not exist" do
    subscribe(conversation_id: 999_999)
    expect(subscription).to be_rejected
  end

  it "rejects subscription when the conversation belongs to another student" do
    other_student   = create(:student, classroom: classroom)
    other_conv      = create(:conversation, student: other_student, subject: exam_subject,
                             tutor_state: TutorState.default)
    subscribe(conversation_id: other_conv.id)
    expect(subscription).to be_rejected
  end
end