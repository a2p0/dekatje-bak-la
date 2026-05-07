require "rails_helper"

RSpec.feature "Student tutor — navigation between questions",
              type: :feature, js: true, tutor_streaming: true do
  let(:classroom) { create(:classroom) }
  let(:student) { create(:student, :with_api_key, classroom: classroom, use_personal_key: true) }
  let(:subject_record) { create(:subject_with_two_questions) }
  let(:q1) { subject_record.parts.first.questions.order(:position).first }
  let(:q2) { subject_record.parts.first.questions.order(:position).second }

  # Active conversation pre-created: drawer connects only if a conversation exists.
  let!(:conversation) do
    create(:conversation, student: student, subject: subject_record,
      lifecycle_state: "active", tutor_state: TutorState.default)
  end

  before do
    create(:classroom_subject, classroom: classroom, subject: subject_record)
    FakeRubyLlm.setup_stub
    login_as_student(student, classroom)
  end

  scenario "drawer filters messages by question — Q1 message not visible on Q2 page" do
    # Pre-seed a message linked to Q1 so the filter is meaningful.
    create(:message, conversation: conversation, role: :user,
      content: "Question 1 message", question: q1)

    visit student_question_path(access_code: classroom.access_code,
      subject_id: subject_record.id, id: q1.id)
    open_tutor_drawer

    # Q1 message is visible when on Q1's page.
    expect(page).to have_content("Question 1 message", wait: 5)

    visit student_question_path(access_code: classroom.access_code,
      subject_id: subject_record.id, id: q2.id)
    open_tutor_drawer

    # Q1 message must NOT appear on Q2's page.
    expect(page).not_to have_content("Question 1 message")
  end

  scenario "no extra messages created on rapid back-and-forth without interaction" do
    visit student_question_path(access_code: classroom.access_code,
      subject_id: subject_record.id, id: q1.id)
    open_tutor_drawer

    initial_count = page.all("[data-message-id]", visible: :all).count

    visit student_question_path(access_code: classroom.access_code,
      subject_id: subject_record.id, id: q2.id)
    visit student_question_path(access_code: classroom.access_code,
      subject_id: subject_record.id, id: q1.id)
    sleep 1
    open_tutor_drawer

    expect(page.all("[data-message-id]", visible: :all).count).to eq(initial_count)
  end
end
