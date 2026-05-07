require "rails_helper"

RSpec.describe "Tutor chips — comportement contextuel", type: :feature, tutor_streaming: true do
  let(:teacher)   { create(:user) }
  let(:classroom) { create(:classroom, owner: teacher) }
  let(:student) do
    create(:student, classroom: classroom,
      api_key: "sk-test-key", api_provider: :anthropic, use_personal_key: true)
  end
  let(:subject_record) do
    create(:subject, status: :published, owner: teacher,
      specific_presentation: "La société CIME")
  end
  let(:part) { create(:part, :specific, subject: subject_record, number: 1, position: 1) }
  let!(:question) do
    create(:question, part: part, number: "1.1",
      label: "Calculer la consommation.", answer_type: :calcul, points: 2, position: 1)
  end
  let!(:answer) { create(:answer, question: question) }
  let!(:classroom_subject) { create(:classroom_subject, classroom: classroom, subject: subject_record) }
  let!(:autonomous_session) do
    create(:student_session, student: student, subject: subject_record, mode: :autonomous)
  end

  before { login_as_student(student, classroom) }

  def open_drawer
    visit student_question_path(
      access_code: classroom.access_code,
      subject_id:  subject_record.id,
      id:          question.id
    )
    find("button[aria-label='Ouvrir le tutorat IA']", match: :first).click
    expect(page).to have_css("[data-chat-drawer-target='drawer'].translate-x-0", visible: :all, wait: 5)
  end

  # Chips fresh (phase dérivée = :fresh pour trace vide) — calcul answer_type
  scenario "cliquer un chip :send envoie le message", js: true do
    FakeRubyLlm.setup_stub(content: "Bonne question !", tool_calls: [])
    create(:conversation,
      student: student, subject: subject_record,
      lifecycle_state: "active", tutor_state: TutorState.default.with(current_question_id: question.id))

    open_drawer
    expect(page).to have_css("[data-chat-connected='true']", wait: 10)

    find("#tutor-chips button", text: "C'est quoi la formule ?").click

    expect(page).to have_text("Quelle formule je dois utiliser ?", wait: 5)
    expect(page).to have_text("Bonne question !", wait: 10)
  end
end
