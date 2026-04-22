require "rails_helper"

RSpec.describe Tutor::UpdateTutorState do
  let(:user)         { create(:user) }
  let(:classroom)    { create(:classroom, owner: user) }
  let(:student)      { create(:student, classroom: classroom) }
  let(:exam_subject) { create(:subject, owner: user, status: :published) }
  let(:conversation) { create(:conversation, student: student, subject: exam_subject) }

  let(:new_state) do
    TutorState.new(
      current_phase:        "guiding",
      current_question_id:  10,
      concepts_mastered:    [ "énergie" ],
      concepts_to_revise:   [],
      discouragement_level: 1,
      question_states:      {}, welcome_sent: false)
  end

  it "persists the updated TutorState and returns ok" do
    result = described_class.call(conversation: conversation, tutor_state: new_state)
    expect(result.ok?).to be true
    reloaded = conversation.reload.tutor_state
    expect(reloaded.current_phase).to eq("guiding")
    expect(reloaded.current_question_id).to eq(10)
    expect(reloaded.concepts_mastered).to eq([ "énergie" ])
    expect(reloaded.discouragement_level).to eq(1)
  end
end