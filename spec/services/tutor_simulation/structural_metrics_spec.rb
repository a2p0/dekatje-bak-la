require "rails_helper"

RSpec.describe TutorSimulation::StructuralMetrics do
  let(:user)            { create(:user) }
  let(:classroom)       { create(:classroom, owner: user) }
  let(:student)         { create(:student, classroom: classroom) }
  let(:exam_subject)    { create(:subject, owner: user, status: :published) }
  let(:part)            { create(:part, subject: exam_subject) }
  let(:question)        { create(:question, part: part) }

  let(:tutor_state) do
    TutorState.new(
      current_phase:        "guiding",
      current_question_id:  question.id,
      concepts_mastered:    [],
      concepts_to_revise:   [],
      discouragement_level: 0,
      question_states:      {
        question.id.to_s => QuestionState.new(
          step: 1, hints_used: 2, last_confidence: nil,
          error_types: [], completed_at: nil
        )
      }
    )
  end

  let(:conversation) do
    create(:conversation, student: student, subject: exam_subject,
           lifecycle_state: "active", tutor_state: tutor_state)
  end

  before do
    create(:message, conversation: conversation, role: :user,      content: "hello")
    create(:message, conversation: conversation, role: :assistant, content: "Bonjour, où sont les données ?")
    create(:message, conversation: conversation, role: :user,      content: "dans DT1")
    create(:message, conversation: conversation, role: :assistant, content: Tutor::FilterSpottingOutput::NEUTRAL_RELAUNCH)
  end

  subject(:metrics) { described_class.compute(conversation: conversation) }

  it "reports the final phase and rank" do
    expect(metrics[:final_phase]).to eq("guiding")
    expect(metrics[:phase_rank]).to eq(4)
  end

  it "computes the average tutor message length in words" do
    expect(metrics[:avg_message_length_words]).to be > 0
  end

  it "computes the open-question ratio (messages ending with '?')" do
    # both assistant messages end with "?": the greeting and the neutral relaunch
    expect(metrics[:open_question_ratio]).to eq(1.0)
  end

  it "counts regex intercepts (assistant messages replaced by the neutral relaunch)" do
    expect(metrics[:regex_intercepts]).to eq(1)
  end

  it "sums hints distributed across question_states" do
    expect(metrics[:hints_used]).to eq(2)
  end

  it "reports message counts per role" do
    expect(metrics[:message_count_assistant]).to eq(2)
    expect(metrics[:message_count_user]).to eq(2)
  end
end
