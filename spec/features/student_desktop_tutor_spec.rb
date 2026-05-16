require "rails_helper"

RSpec.describe "Story 064-US3: Tutorat Tibo en desktop", type: :feature do
  let(:teacher)   { create(:user, openrouter_api_key: "sk-or-test") }
  let(:classroom) { create(:classroom, owner: teacher, name: "Terminale SIN 2026", tutor_free_mode_enabled: true) }
  let(:student) do
    create(:student, classroom: classroom, api_key: "sk-test", api_provider: :anthropic)
  end
  let(:subject_record) do
    create(:subject,
      status: :published,
      owner: teacher,
      specific_presentation: "Société CIME — véhicules électriques.")
  end
  let(:part) do
    create(:part, :specific,
      subject: subject_record,
      number: 1,
      title: "Transport et développement durable",
      objective_text: "Comparer les modes de transport en termes d'impact environnemental.",
      position: 1)
  end
  let!(:question) do
    create(:question,
      part: part,
      number: "1.1",
      label: "Calculer la consommation en litres pour 186 km.",
      points: 2,
      position: 1)
  end
  let!(:answer) { create(:answer, question: question) }
  let!(:classroom_subject) { create(:classroom_subject, classroom: classroom, subject: subject_record) }

  def visit_question_page
    visit student_question_path(
      access_code: classroom.access_code,
      subject_id: subject_record.id,
      id: question.id
    )
  end

  scenario "le drawer Tibo desktop expose un panneau contexte (60/40 chat | contexte)", js: true do
    FakeRubyLlm.setup_stub(content: "Bonjour", tool_calls: [])
    login_as_student(student, classroom)
    visit_question_page

    # The desktop navbar Tibo button is the first one in DOM order
    find("button[aria-label='Ouvrir le tutorat IA']", match: :first).click

    # Drawer slides in
    expect(page).to have_css(
      "[data-chat-drawer-target='drawer'].translate-x-0",
      visible: :all, wait: 5
    )

    # Context panel (desktop only) is visible inside the drawer
    context_panel = find("[data-064-context-panel]", visible: :all)
    expect(context_panel).to have_text(question.label, visible: :all)
    expect(context_panel).to have_text("Partie 1", visible: :all)
    expect(context_panel).to have_text(part.objective_text, visible: :all)
  end

  scenario "le drawer Tibo desktop a la classe lg:basis-3/5 sur le pane chat" do
    login_as_student(student, classroom)
    visit_question_page

    chat_pane = find("[data-064-chat-pane]", visible: :all)
    expect(chat_pane[:class]).to include("lg:basis-3/5")
  end

  scenario "fermer le drawer ramène la colonne DT visible (translate-x-full)", js: true do
    FakeRubyLlm.setup_stub(content: "Bonjour", tool_calls: [])
    login_as_student(student, classroom)
    visit_question_page

    find("button[aria-label='Ouvrir le tutorat IA']", match: :first).click
    expect(page).to have_css(
      "[data-chat-drawer-target='drawer'].translate-x-0",
      visible: :all, wait: 5
    )

    find("button[aria-label='Fermer le tutorat']", wait: 5).click

    expect(page).to have_css(
      "[data-chat-drawer-target='drawer'].translate-x-full",
      visible: :all, wait: 15
    )
  end
end
