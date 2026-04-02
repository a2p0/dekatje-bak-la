# spec/features/student_tutor_chat_spec.rb
require "rails_helper"

RSpec.describe "Story 10: Chat adaptatif avec contexte de reperage", type: :feature do
  let(:teacher) { create(:user) }
  let(:classroom) { create(:classroom, name: "Terminale SIN 2026", owner: teacher) }
  let(:student)   { create(:student, classroom: classroom, api_key: "sk-test", api_provider: :anthropic) }
  let(:subject_record) do
    create(:subject,
      title: "BAC STI2D Metropole 2025",
      status: :published,
      owner: teacher,
      presentation_text: "La societe CIME fabrique des vehicules electriques.")
  end

  let(:part) do
    create(:part,
      subject: subject_record,
      number: 1,
      title: "Transport et developpement durable",
      objective_text: "Comparer les modes de transport.",
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

  let!(:answer) do
    create(:answer,
      question: question,
      correction_text: "Car = 56,73 l",
      explanation_text: "Formule Consommation x Distance / 100")
  end

  let!(:classroom_subject) { create(:classroom_subject, classroom: classroom, subject: subject_record) }

  def visit_question_page
    visit student_question_path(
      access_code: classroom.access_code,
      subject_id: subject_record.id,
      id: question.id
    )
  end

  context "en mode tutorat avec la correction affichee" do
    let(:tutored_session) do
      create(:student_session,
        student: student,
        subject: subject_record,
        mode: :tutored,
        progression: { question.id.to_s => { "answered" => true } },
        tutor_state: {
          "question_states" => {
            question.id.to_s => { "step" => "feedback" }
          }
        }
      )
    end

    scenario "le lien 'Expliquer la correction' est visible apres la correction", js: true do
      tutored_session
      login_as_student(student, classroom)
      visit_question_page

      expect(page).to have_button("Expliquer la correction")
    end

    scenario "cliquer sur 'Expliquer la correction' ouvre le chat drawer", js: true do
      tutored_session
      login_as_student(student, classroom)
      visit_question_page

      click_button "Expliquer la correction"

      expect(page).to have_css("[data-chat-target='drawer']", visible: true)
    end
  end

  context "en mode autonome avec la correction affichee" do
    let(:autonomous_session) do
      create(:student_session,
        student: student,
        subject: subject_record,
        mode: :autonomous,
        progression: { question.id.to_s => { "answered" => true } }
      )
    end

    scenario "le lien 'Expliquer la correction' n'est PAS visible en mode autonome", js: true do
      autonomous_session
      login_as_student(student, classroom)
      visit_question_page

      expect(page).not_to have_button("Expliquer la correction")
    end
  end
end
