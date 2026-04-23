require "rails_helper"

RSpec.describe ProcessTutorMessageJob, type: :job do
  let(:user)         { create(:user) }
  let(:classroom)    { create(:classroom, owner: user) }
  let(:student)      { create(:student, classroom: classroom, api_key: "sk-test", api_provider: :anthropic, use_personal_key: true) }
  let(:exam_subject) { create(:subject, owner: user, status: :published) }
  let(:part)         { create(:part, subject: exam_subject) }
  let(:question)     { create(:question, part: part) }
  let(:conversation) do
    create(:conversation, student: student, subject: exam_subject,
           lifecycle_state: "active", tutor_state: TutorState.default)
  end

  before do
    allow(Tutor::ProcessMessage).to receive(:call).and_return(Tutor::Result.ok)
  end

  it "calls Tutor::ProcessMessage with correct arguments" do
    described_class.perform_now(conversation.id, "Bonjour.", question.id)

    expect(Tutor::ProcessMessage).to have_received(:call).with(
      conversation:  conversation,
      student_input: "Bonjour.",
      question:      question
    )
  end

  it "broadcasts an error message when pipeline returns err" do
    allow(Tutor::ProcessMessage).to receive(:call).and_return(
      Tutor::Result.err("Erreur test")
    )
    expect(ActionCable.server).to receive(:broadcast).with(
      "conversation_#{conversation.id}",
      { error: "Erreur test" }
    )
    described_class.perform_now(conversation.id, "Bonjour.", question.id)
  end

  it "can be enqueued" do
    expect {
      described_class.perform_later(conversation.id, "test", question.id)
    }.to have_enqueued_job(described_class)
  end
end
