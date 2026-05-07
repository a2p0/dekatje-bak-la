require "rails_helper"

RSpec.describe Tutor::RecordEvent do
  let(:student) { create(:student) }
  let(:subject_record) { create(:subject) }
  let!(:question) { create(:question, part: create(:part, subject: subject_record)) }
  let!(:conversation) do
    create(:conversation, student: student, subject: subject_record, tutor_state: TutorState.default)
  end

  describe "appending an event to the current question's trace" do
    it "appends and persists the event" do
      result = described_class.call(
        conversation: conversation,
        question_id:  question.id,
        type:         "viewed_data_hints",
        source:       "page_click"
      )

      expect(result.ok?).to be(true)
      conversation.reload
      trace = conversation.tutor_state.trace_for(question.id)
      expect(trace.events.length).to eq(1)
      expect(trace.events.first["type"]).to eq("viewed_data_hints")
      expect(trace.events.first["source"]).to eq("page_click")
      expect(trace.events.first).to have_key("at")
    end

    it "is append-only (existing events untouched)" do
      described_class.call(conversation: conversation, question_id: question.id,
                           type: "viewed_data_hints", source: "page_click")
      described_class.call(conversation: conversation, question_id: question.id,
                           type: "student_attempt", source: "llm_message",
                           content: "5673", verdict: "incorrect")

      conversation.reload
      trace = conversation.tutor_state.trace_for(question.id)
      expect(trace.events.map { |e| e["type"] }).to eq(%w[viewed_data_hints student_attempt])
    end

    it "updates current_question_id when navigated_here event is recorded" do
      described_class.call(conversation: conversation, question_id: question.id,
                           type: "navigated_here", source: "code")

      conversation.reload
      expect(conversation.tutor_state.current_question_id).to eq(question.id)
    end

    it "does not alter current_question_id for non-navigation events" do
      conversation.update!(tutor_state: TutorState.default.with(current_question_id: 999))
      described_class.call(conversation: conversation, question_id: question.id,
                           type: "viewed_data_hints", source: "page_click")

      conversation.reload
      expect(conversation.tutor_state.current_question_id).to eq(999)
    end
  end

  describe "invariant: append-only" do
    it "preserves all prior events and their order" do
      events = []
      5.times do |i|
        described_class.call(conversation: conversation, question_id: question.id,
                             type: "tutor_gave", source: "classifier", what: "formule")
        events << "tutor_gave"
      end

      conversation.reload
      trace = conversation.tutor_state.trace_for(question.id)
      expect(trace.events.map { |e| e["type"] }).to eq(events)
    end
  end
end
