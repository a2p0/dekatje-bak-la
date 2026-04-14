require "rails_helper"

RSpec.describe Tutor::ProcessMessage do
  let(:user)         { create(:user) }
  let(:classroom)    { create(:classroom, owner: user) }
  let(:student)      { create(:student, classroom: classroom, api_key: "sk-test", api_provider: :anthropic, use_personal_key: true) }
  let(:exam_subject) { create(:subject, owner: user, status: :published) }
  let!(:cs)          { create(:classroom_subject, classroom: classroom, subject: exam_subject) }
  let(:part)         { create(:part, subject: exam_subject) }
  let(:question)     { create(:question, part: part) }
  let!(:answer)      { create(:answer, question: question, correction_text: "R = 10 Ω") }
  let(:conversation) do
    create(:conversation, student: student, subject: exam_subject,
           lifecycle_state: "active", tutor_state: TutorState.default)
  end

  before do
    FakeRubyLlm.setup_stub(content: "Qu'avez-vous tenté ?", tool_calls: [])
    allow(ActionCable.server).to receive(:broadcast)
  end

  subject(:result) do
    described_class.call(
      conversation:  conversation,
      student_input: "Je ne sais pas.",
      question:      question
    )
  end

  it "returns ok" do
    expect(result.ok?).to be true
  end

  it "persists a user message" do
    expect { result }.to change(Message.where(role: :user), :count).by(1)
  end

  it "persists an assistant message with content" do
    result
    assistant_msg = Message.where(role: :assistant).last
    expect(assistant_msg).not_to be_nil
    expect(assistant_msg.content).to eq("Qu'avez-vous tenté ?")
  end

  it "broadcasts the assistant message" do
    result
    expect(ActionCable.server).to have_received(:broadcast).with(
      "conversation_#{conversation.id}",
      anything
    )
  end

  it "returns err for blank input" do
    r = described_class.call(
      conversation:  conversation,
      student_input: "   ",
      question:      question
    )
    expect(r.err?).to be true
  end
end
