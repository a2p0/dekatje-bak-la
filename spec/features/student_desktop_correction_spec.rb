require "rails_helper"

RSpec.describe "Story 064-US2: Correction en desktop", type: :feature do
  let(:classroom) { create(:classroom, name: "Terminale SIN 2026") }
  let(:student)   { create(:student, classroom: classroom) }
  let(:subject) do
    create(:subject,
      status: :published,
      specific_presentation: "Société CIME — véhicules électriques.")
  end

  let(:part) do
    create(:part, :specific,
      subject: subject,
      number: 1,
      title: "Transport et développement durable",
      objective_text: "Comparer les modes de transport.",
      position: 1)
  end

  let!(:question) do
    create(:question,
      part: part,
      number: "1.1",
      label: "Calculer la consommation en litres pour 186 km.",
      points: 2,
      position: 1,
      dt_references: [ "DT1" ])
  end

  let!(:answer) do
    create(:answer,
      question: question,
      correction_text: "Car = 56,73 l",
      explanation_text: "Consommation × Distance / 100",
      data_hints: [
        { "source" => "DT1", "location" => "tableau Consommation moyenne" },
        { "source" => "enonce", "location" => "distance 186 km" }
      ])
  end

  let!(:classroom_subject) { create(:classroom_subject, classroom: classroom, subject: subject) }

  def visit_question_page
    visit student_question_path(
      access_code: classroom.access_code,
      subject_id: subject.id,
      id: question.id
    )
  end

  scenario "le DT viewer affiche un bandeau 'Donnée utile' avec source et location quand l'élève a répondu" do
    login_as_student(student, classroom)
    visit_question_page
    click_button "Voir la correction"

    # The DT viewer aside (right column) should now show the data hint banner
    dt_viewer = find("aside[aria-label='Document technique']", visible: :all)
    banner = dt_viewer.find("[data-064-data-hint-banner]", visible: :all)
    expect(banner).to have_text("Donnée utile")
    expect(banner).to have_text("DT1")
    expect(banner).to have_text("tableau Consommation moyenne")
  end

  scenario "avant correction, le DT viewer ne montre pas le bandeau 'Donnée utile'" do
    login_as_student(student, classroom)
    visit_question_page

    dt_viewer = find("aside[aria-label='Document technique']", visible: :all)
    expect(dt_viewer).not_to have_css("[data-064-data-hint-banner]", visible: :all)
  end

  scenario "la colonne gauche affiche les cartes correction (réponse, calcul, data hints)" do
    login_as_student(student, classroom)
    visit_question_page
    click_button "Voir la correction"

    expect(page).to have_text("Car = 56,73 l")
    expect(page).to have_text("Consommation × Distance / 100")
    expect(page).to have_text("Où trouver les données ?")
  end
end
