require "rails_helper"

RSpec.describe "Parcours tuteur complet (E2E)", type: :feature, tutor_streaming: true do
  let(:teacher)   { create(:user) }
  let(:classroom) { create(:classroom, owner: teacher) }
  let(:student) do
    create(:student, classroom: classroom,
      api_key: "sk-test-key", api_provider: :anthropic, use_personal_key: true)
  end
  let(:subject_record) do
    create(:subject,
      status: :published, owner: teacher,
      specific_presentation: "La société CIME fabrique des véhicules électriques.")
  end
  let(:part) do
    create(:part, :specific, subject: subject_record,
      number: 1, title: "Transport et DD",
      objective_text: "Comparer les modes.", position: 1)
  end
  let!(:question) do
    create(:question, part: part,
      number: "1.1",
      label: "Calculer la consommation en litres pour 186 km.",
      answer_type: :calculation, points: 2, position: 1)
  end
  let!(:answer) { create(:answer, question: question) }
  let!(:classroom_subject) { create(:classroom_subject, classroom: classroom, subject: subject_record) }

  let!(:autonomous_session) do
    create(:student_session,
      student: student, subject: subject_record, mode: :autonomous)
  end

  before { login_as_student(student, classroom) }

  scenario "activation : clic 'Activer le tuteur' crée une conversation et remplace le banner", js: true do
    visit student_subject_path(access_code: classroom.access_code, id: subject_record.id)

    expect(page).to have_button("Activer le tuteur")

    click_button "Activer le tuteur"

    expect(page).to have_text("Mode tuteur activé", wait: 5)
    expect(page).to have_link("Commencer")

    conv = Conversation.find_by(student: student, subject: subject_record)
    expect(conv).to be_present
    expect(conv.lifecycle_state).to eq("active")
  end

  scenario "no API key : le banner d'activation n'est pas rendu", js: true do
    student.update!(api_key: nil, use_personal_key: true)

    visit student_subject_path(access_code: classroom.access_code, id: subject_record.id)

    expect(page).not_to have_button("Activer le tuteur")
  end

  scenario "persistance : rouvrir le drawer conserve les messages précédents", js: true do
    conv = create(:conversation,
      student: student, subject: subject_record,
      lifecycle_state: "active", tutor_state: TutorState.default)
    create(:message, conversation: conv, role: :user,      content: "Premier message élève")
    create(:message, conversation: conv, role: :assistant, content: "Réponse du tuteur")

    visit student_question_path(
      access_code: classroom.access_code,
      subject_id:  subject_record.id,
      id:          question.id
    )
    expect(page).to have_css("[data-chat-connected='true']", wait: 10)

    find("button[aria-label='Ouvrir le tutorat IA']", match: :first).click

    drawer = find("[data-chat-drawer-target='drawer']", visible: :all)
    expect(drawer).to have_text("Premier message élève", wait: 5)
    expect(drawer).to have_text("Réponse du tuteur")

    find("button[aria-label='Fermer le tutorat']").click

    expect(page).to have_css(
      "[data-chat-drawer-target='drawer'].translate-x-full",
      visible: :all, wait: 5
    )

    find("button[aria-label='Ouvrir le tutorat IA']", match: :first).click

    drawer_reopened = find("[data-chat-drawer-target='drawer']", visible: :all)
    expect(drawer_reopened).to have_text("Premier message élève")
    expect(drawer_reopened).to have_text("Réponse du tuteur")
  end
end
