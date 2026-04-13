require "rails_helper"

RSpec.xdescribe "Tuteur guidé : micro-tâches de repérage", type: :feature do
  let(:teacher) { create(:user) }
  let(:classroom) { create(:classroom, name: "Terminale SIN 2026", owner: teacher) }
  let(:student) { create(:student, classroom: classroom, api_key: "sk-test", api_provider: :anthropic) }
  let(:exam_session) do
    create(:exam_session, owner: teacher,
      common_presentation: "La société CIME fabrique des véhicules électriques.")
  end
  let(:subject_record) do
    create(:subject, status: :published, owner: teacher, exam_session: exam_session,
      specific_presentation: "Spécialité SIN du sujet CIME.")
  end
  let(:part) do
    create(:part, :specific, subject: subject_record,
      number: 1, title: "Transport et DD", objective_text: "Comparer les modes.", position: 1)
  end
  let!(:question) do
    create(:question, part: part, number: "1.1",
      label: "Calculer la consommation en litres pour 186 km.",
      answer_type: :calculation, points: 2, position: 1)
  end
  let!(:answer) do
    create(:answer, question: question,
      correction_text: "Car = 56,73 l",
      explanation_text: "Formule Consommation x Distance / 100",
      data_hints: [
        { "source" => "DT1", "location" => "tableau Consommation moyenne" },
        { "source" => "mise_en_situation", "location" => "distance 186 km" }
      ])
  end
  let!(:classroom_subject) { create(:classroom_subject, classroom: classroom, subject: subject_record) }

  def visit_question_page
    visit student_question_path(
      access_code: classroom.access_code,
      subject_id: subject_record.id,
      id: question.id
    )
  end

  context "en mode tuteur" do
    let!(:tutored_session) do
      create(:student_session,
        student: student, subject: subject_record,
        mode: :tutored, progression: {},
        tutor_state: {})
    end

    before do
      login_as_student(student, classroom)
    end

    scenario "l'encart 'Avant de répondre' s'affiche et bloque la correction", js: true do
      visit_question_page

      expect(page).to have_text("Avant de répondre")
      expect(page).to have_button("Vérifier")
      expect(page).not_to have_button("Voir la correction")
    end

    scenario "sélectionner le bon type et les bonnes sources affiche un feedback positif", js: true do
      visit_question_page

      choose("Calculer une valeur")
      check("Document Technique (DT)")
      check("Mise en situation")
      click_button "Vérifier"

      expect(page).to have_text("Avant de répondre — résultats", wait: 5)
      expect(page).to have_text("✓")
    end

    scenario "sélectionner un mauvais type affiche le type incorrect et le bon", js: true do
      visit_question_page

      # Pick any wrong radio option (not "Calculer une valeur")
      wrong_option = all("input[name='task_type']").find { |r| r.value != "calculation" }
      wrong_option.click
      check("Document Technique (DT)")
      check("Mise en situation")
      click_button "Vérifier"

      expect(page).to have_text("Avant de répondre — résultats", wait: 5)
      expect(page).to have_text("✗")
      expect(page).to have_text("Bonne réponse")
      expect(page).to have_text("Calculer une valeur")
    end

    scenario "oublier une source affiche un avertissement avec la location", js: true do
      visit_question_page

      choose("Calculer une valeur")
      check("Document Technique (DT)")
      # Ne pas cocher "Mise en situation"
      click_button "Vérifier"

      expect(page).to have_text("Avant de répondre — résultats", wait: 5)
      expect(page).to have_text("⚠")
      expect(page).to have_text("mise_en_situation")
      expect(page).to have_text("distance 186 km")
    end

    scenario "cocher une source en trop affiche 'non nécessaire'", js: true do
      visit_question_page

      choose("Calculer une valeur")
      check("Document Technique (DT)")
      check("Mise en situation")
      check("Énoncé de la question")
      click_button "Vérifier"

      expect(page).to have_text("Avant de répondre — résultats", wait: 5)
      expect(page).to have_text("non nécessaire")
      expect(page).to have_text("enonce")
    end

    scenario "cliquer 'passer' fait disparaître l'encart et affiche la correction", js: true do
      visit_question_page

      expect(page).to have_text("Avant de répondre")
      click_on "passer"

      expect(page).to have_button("Voir la correction", wait: 5)
      expect(page).not_to have_button("Vérifier")
    end

    scenario "revisiter une question avec spotting déjà fait affiche le feedback", js: true do
      tutored_session.update!(tutor_state: {
        "question_states" => {
          question.id.to_s => {
            "step" => "feedback",
            "spotting" => {
              "task_type_answer" => "calculation",
              "task_type_correct" => true,
              "sources_answer" => [ "dt", "mise_en_situation" ],
              "sources_correct" => [ "dt", "mise_en_situation" ],
              "sources_missed" => [],
              "sources_extra" => [],
              "completed_at" => Time.current.iso8601
            }
          }
        }
      })

      visit_question_page

      expect(page).to have_text("Avant de répondre — résultats")
      expect(page).to have_css(".text-emerald-600, .dark\\:text-emerald-400", text: "✓")
      expect(page).to have_button("Voir la correction")
      expect(page).not_to have_button("Vérifier")
    end
  end

  context "en mode autonome" do
    let!(:autonomous_session) do
      create(:student_session,
        student: student, subject: subject_record,
        mode: :autonomous, progression: {})
    end

    scenario "l'encart de repérage ne s'affiche pas", js: true do
      login_as_student(student, classroom)
      visit_question_page

      expect(page).not_to have_text("Avant de répondre")
      expect(page).to have_button("Voir la correction")
    end
  end
end
