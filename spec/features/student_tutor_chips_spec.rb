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

  def tutor_state_at(phase)
    TutorState.new(
      current_phase: phase, current_question_id: question.id,
      concepts_mastered: [], concepts_to_revise: [], discouragement_level: 0,
      question_states: {}, welcome_sent: true, last_activity_at: nil)
  end

  scenario "phase guiding — chips Un indice, Reformule, Définis visibles", js: true do
    create(:conversation,
      student: student, subject: subject_record,
      lifecycle_state: "active", tutor_state: tutor_state_at("guiding"))

    open_drawer

    expect(page).to have_css("#tutor-chips button", text: "Un indice")
    expect(page).to have_css("#tutor-chips button", text: "Reformule")
    expect(page).to have_css("#tutor-chips button", text: "Définis")
  end

  scenario "phase guiding MAX_HINTS — Un indice grisé", js: true do
    TutorState  # force autoload so QuestionState constant is defined
    ts = TutorState.new(
      current_phase: "guiding", current_question_id: question.id,
      concepts_mastered: [], concepts_to_revise: [], discouragement_level: 0,
      question_states: { question.id.to_s => QuestionState.new(
        phase: "guiding", step: nil, hints_used: 5,
        last_confidence: nil, error_types: [], completed_at: nil, intro_seen: false
      ) },
      welcome_sent: true, last_activity_at: nil)

    create(:conversation,
      student: student, subject: subject_record,
      lifecycle_state: "active", tutor_state: ts)

    open_drawer

    hint_button = find("#tutor-chips button", text: "Un indice")
    expect(hint_button[:disabled]).to be_truthy
  end

  scenario "phase validating — chips confidence affichées, input désactivé", js: true do
    create(:conversation,
      student: student, subject: subject_record,
      lifecycle_state: "validating", tutor_state: tutor_state_at("validating"))

    open_drawer

    expect(page).to have_css("#tutor-chips [data-chip-action='confidence']", count: 5)
    expect(page).to have_css("#tutor-chips button", text: /Pas du tout sûr/)
    expect(page).to have_css("#tutor-chips button", text: /Très sûr/)
    input = find("[data-tutor-chat-target='input']", visible: :all)
    expect(input[:disabled]).to be_truthy
  end

  scenario "cliquer chip :send envoie le message", js: true do
    FakeRubyLlm.setup_stub(content: "Bonne question !", tool_calls: [])
    create(:conversation,
      student: student, subject: subject_record,
      lifecycle_state: "active", tutor_state: tutor_state_at("guiding"))

    open_drawer
    expect(page).to have_css("[data-chat-connected='true']", wait: 10)

    find("#tutor-chips button", text: "Reformule").click

    expect(page).to have_text("Peux-tu reformuler la question ?", wait: 5)
    expect(page).to have_text("Bonne question !", wait: 10)
  end
end
