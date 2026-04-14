require "rails_helper"

RSpec.describe "Story 10: Tutor chat drawer (Vague 4)", type: :feature do
  let(:teacher)   { create(:user) }
  let(:classroom) { create(:classroom, name: "Terminale SIN 2026", owner: teacher) }
  let(:student) do
    create(:student, classroom: classroom, api_key: "sk-test", api_provider: :anthropic)
  end
  let(:subject_record) do
    create(:subject,
      status: :published,
      owner:  teacher,
      specific_presentation: "La société CIME fabrique des véhicules électriques.")
  end
  let(:part) do
    create(:part, :specific,
      subject: subject_record,
      number:  1,
      title:   "Transport et développement durable",
      objective_text: "Comparer les modes de transport.",
      position: 1)
  end
  let!(:question) do
    create(:question,
      part:     part,
      number:   "1.1",
      label:    "Calculer la consommation en litres pour 186 km.",
      points:   2,
      position: 1)
  end
  let!(:answer) do
    create(:answer,
      question:        question,
      correction_text: "Car = 56,73 l",
      explanation_text: "Formule Consommation × Distance / 100")
  end
  let!(:classroom_subject) { create(:classroom_subject, classroom: classroom, subject: subject_record) }

  def visit_question_page
    visit student_question_path(
      access_code: classroom.access_code,
      subject_id:  subject_record.id,
      id:          question.id
    )
  end

  context "when a conversation exists (tutor activated)" do
    let!(:active_conversation) do
      create(:conversation,
        student:         student,
        subject:         subject_record,
        lifecycle_state: "active",
        tutor_state:     TutorState.default)
    end

    before do
      login_as_student(student, classroom)
      visit_question_page
    end

    scenario "clicking the Tutorat button slides the drawer into view", js: true do
      expect(page).to have_css("[data-chat-connected='true']", wait: 10)

      find("button[aria-label='Ouvrir le tutorat IA']", match: :first).click

      expect(page).to have_css(
        "[data-chat-drawer-target='drawer'].translate-x-0",
        visible: :all, wait: 5
      )
      expect(page).to have_css("[data-tutor-chat-target='input']", visible: :all)
      expect(page).to have_css("[data-tutor-chat-target='sendButton']", visible: :all)
    end

    scenario "closing the drawer slides it back out", js: true do
      expect(page).to have_css("[data-chat-connected='true']", wait: 10)

      find("button[aria-label='Ouvrir le tutorat IA']", match: :first).click
      expect(page).to have_css(
        "[data-chat-drawer-target='drawer'].translate-x-0",
        visible: :all, wait: 5
      )

      find("button[aria-label='Fermer le tutorat']").click

      expect(page).to have_css(
        "[data-chat-drawer-target='drawer'].translate-x-full",
        visible: :all, wait: 5
      )
    end
  end

  context "when no conversation exists yet" do
    before do
      login_as_student(student, classroom)
      visit_question_page
    end

    scenario "the drawer is present but the input is disabled until activation", js: true do
      find("button[aria-label='Ouvrir le tutorat IA']", match: :first).click

      expect(page).to have_css(
        "[data-chat-drawer-target='drawer'].translate-x-0",
        visible: :all, wait: 5
      )
      input = find("[data-tutor-chat-target='input']", visible: :all)
      expect(input[:disabled]).to be_truthy
    end
  end
end
