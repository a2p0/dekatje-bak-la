require "rails_helper"

RSpec.feature "Student tutor — cap on final result chip", type: :feature, js: true do
  let(:teacher)   { create(:user) }
  let(:classroom) { create(:classroom, owner: teacher) }
  let(:student)   { create(:student, :with_api_key, classroom: classroom) }
  let(:subject_record) { create(:subject, status: :published, owner: teacher) }
  let(:part)    { create(:part, subject: subject_record, number: 1, position: 1) }
  let(:question) do
    create(:question, part: part, status: :validated, answer_type: :calcul,
                      number: "1.1", label: "Calculer la consommation.")
  end
  let!(:answer) { create(:answer, question: question) }

  before do
    create(:classroom_subject, classroom: classroom, subject: subject_record)
    FakeRubyLlm.setup_stub
    login_as_student(student, classroom)
  end

  scenario "Donne le résultat chip is disabled when cap is active (1 incorrect attempt)" do
    # Pre-create conversation with 1 incorrect student_attempt → debug phase, cap active.
    # cap_active? = !viewed_correction && attempts_count < 2 → true (1 < 2, no correction viewed).
    conv = Student::EnsureConversation.call(student: student, subject: subject_record)
    conv.update!(lifecycle_state: "active")
    Tutor::RecordEvent.call(
      conversation: conv, question_id: question.id,
      type: "student_attempt", source: "llm_message",
      content: "wrong answer", verdict: "incorrect"
    )

    visit student_question_path(
      access_code: classroom.access_code,
      subject_id:  subject_record.id,
      id:          question.id
    )
    open_tutor_drawer

    expect(page).to have_button("Donne le résultat", disabled: true, wait: 5)
  end

  scenario "Donne le résultat chip is enabled when cap is cleared (2 incorrect attempts)" do
    # Pre-create conversation with 2 incorrect student_attempts → debug phase, cap cleared.
    # cap_active? = !viewed_correction && attempts_count < 2 → false (2 >= 2).
    conv = Student::EnsureConversation.call(student: student, subject: subject_record)
    conv.update!(lifecycle_state: "active")
    2.times do |i|
      Tutor::RecordEvent.call(
        conversation: conv, question_id: question.id,
        type: "student_attempt", source: "llm_message",
        content: "wrong answer #{i}", verdict: "incorrect"
      )
    end

    visit student_question_path(
      access_code: classroom.access_code,
      subject_id:  subject_record.id,
      id:          question.id
    )
    open_tutor_drawer

    expect(page).to have_button("Donne le résultat", disabled: false, wait: 5)
  end
end
