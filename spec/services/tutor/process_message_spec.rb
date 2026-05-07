require "rails_helper"

RSpec.describe Tutor::ProcessMessage do
  let(:student) { create(:student) }
  let(:subject_record) { create(:subject) }
  let(:part) { create(:part, subject: subject_record) }
  let(:question) { create(:question, part: part, answer_type: "calcul") }
  let!(:answer) { create(:answer, question: question, structured_correction: { "input_data" => [], "final_answers" => [] }) }
  let(:conversation) { create(:conversation, student: student, subject: subject_record) }

  before do
    allow(Tutor::CallLlm).to receive(:call).and_return(
      Tutor::Result.ok(full_content: "Bien, prends la formule λS·ΔT/e.")
    )
    allow(Tutor::Classify).to receive(:call).and_return(
      Tutor::Result.ok(annotation: { "gives_formula" => true, "concepts" => [ "conductivité" ] })
    )
    allow(Tutor::BroadcastDone).to receive(:call).and_return(Tutor::Result.ok)
  end

  it "validates input, records the student attempt, calls LLM, classifies, records tutor events, broadcasts" do
    result = described_class.call(
      conversation:  conversation,
      student_input: "5673",
      question:      question,
      access_code:   "tutor-sim"
    )

    expect(result.ok?).to be(true)
    expect(Tutor::CallLlm).to have_received(:call)
    expect(Tutor::Classify).to have_received(:call)
    expect(Tutor::BroadcastDone).to have_received(:call)

    conversation.reload
    trace = conversation.tutor_state.trace_for(question.id)
    types = trace.events.map { |e| e["type"] }

    expect(types).to include("student_attempt")
    expect(types).to include("tutor_gave")  # because gives_formula was true
    expect(conversation.tutor_state.concepts_seen).to include("conductivité")
  end

  it "marks greeted=true after the first turn" do
    expect(conversation.tutor_state.greeted).to be(false)
    described_class.call(conversation: conversation, student_input: "Salut",
                         question: question, access_code: "tutor-sim")
    expect(conversation.reload.tutor_state.greeted).to be(true)
  end

  it "records cap_violation when classifier reports gives_result while cap is active" do
    allow(Tutor::Classify).to receive(:call).and_return(
      Tutor::Result.ok(annotation: { "gives_result" => true, "concepts" => [] })
    )

    described_class.call(conversation: conversation, student_input: "test",
                         question: question, access_code: "tutor-sim")

    types = conversation.reload.tutor_state.trace_for(question.id).events.map { |e| e["type"] }
    expect(types).to include("cap_violation")
  end
end
