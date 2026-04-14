require "rails_helper"

RSpec.describe Tutor::BuildContext do
  let(:user)          { create(:user) }
  let(:classroom)     { create(:classroom, owner: user) }
  let(:student)       { create(:student, classroom: classroom) }
  let(:exam_subject)  { create(:subject, owner: user, status: :published, specialty: :SIN) }
  let!(:cs)           { create(:classroom_subject, classroom: classroom, subject: exam_subject) }
  let(:part)          { create(:part, subject: exam_subject, title: "Partie 1", objective_text: "Analyser le système.") }
  let(:question)      { create(:question, part: part, label: "Calculer la puissance.", context_text: "P = U × I") }
  let!(:answer)       { create(:answer, question: question, correction_text: "P = 230 × 2 = 460 W") }
  let(:conversation) do
    create(:conversation, student: student, subject: exam_subject,
           tutor_state: TutorState.default)
  end

  subject(:result) do
    described_class.call(
      conversation:  conversation,
      question:      question,
      student_input: "<student_input>Je ne sais pas.</student_input>"
    )
  end

  it "returns ok" do
    expect(result.ok?).to be true
  end

  it "includes system prompt with pedagogical rules" do
    expect(result.value[:system_prompt]).to include("Ne jamais donner la réponse directement")
    expect(result.value[:system_prompt]).to include("Maximum 60 mots par message")
  end

  it "includes subject context in system prompt" do
    expect(result.value[:system_prompt]).to include("Calculer la puissance.")
    expect(result.value[:system_prompt]).to include("P = U × I")
  end

  it "includes confidential correction in system prompt" do
    expect(result.value[:system_prompt]).to include("P = 230 × 2 = 460 W")
  end

  it "includes learner model from TutorState" do
    expect(result.value[:system_prompt]).to include("Phase courante")
  end

  it "returns a messages array" do
    expect(result.value[:messages]).to be_an(Array)
  end

  it "limits messages to last 40" do
    45.times { |i| create(:message, conversation: conversation, role: :user, content: "msg #{i}") }
    r = described_class.call(
      conversation:  conversation,
      question:      question,
      student_input: "<student_input>test</student_input>"
    )
    expect(r.value[:messages].length).to be <= 40
  end
end
