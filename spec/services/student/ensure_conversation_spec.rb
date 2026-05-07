require "rails_helper"

RSpec.describe Student::EnsureConversation do
  let(:classroom) { create(:classroom) }
  let(:student) { create(:student, classroom: classroom) }
  let(:subject_obj) { create(:subject) }

  it "creates a disabled conversation with TutorState.default for new (student, subject)" do
    expect {
      described_class.call(student: student, subject: subject_obj)
    }.to change(Conversation, :count).by(1)
    conv = Conversation.last
    expect(conv).to be_disabled
    expect(conv.tutor_state).to eq(TutorState.default)
  end

  it "returns the existing conversation if one already exists" do
    existing = create(:conversation, student: student, subject: subject_obj)
    result = described_class.call(student: student, subject: subject_obj)
    expect(result).to eq(existing)
  end
end
