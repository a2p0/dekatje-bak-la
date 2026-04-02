require "rails_helper"

RSpec.describe "Story 7: Révélation de la correction", type: :feature do
  let(:classroom) { create(:classroom, name: "Terminale SIN 2026") }
  let(:student)   { create(:student, classroom: classroom) }
  let(:subject) do
    create(:subject,
      title: "BAC STI2D Metropole 2025",
      status: :published,
      presentation_text: "La société CIME fabrique des véhicules électriques.")
  end

  let(:part) do
    create(:part,
      subject: subject,
      number: 1,
      title: "Transport et développement durable",
      objective_text: "Comparer les modes de transport.",
      position: 1)
  end

  let!(:q1) do
    create(:question,
      part: part,
      number: "1.1",
      label: "Calculer la consommation en litres pour 186 km.",
      points: 2,
      position: 1)
  end

  let!(:q2) do
    create(:question,
      part: part,
      number: "1.2",
      label: "Comparer les émissions de CO2 des deux véhicules.",
      points: 3,
      position: 2)
  end

  let!(:answer1) do
    create(:answer,
      question: q1,
      correction_text: "Car = 56,73 l / Van = 38,68 kWh",
      explanation_text: "On utilise la formule Consommation × Distance / 100",
      key_concepts: [ "énergie primaire", "rendement" ],
      data_hints: [
        { "source" => "DT", "location" => "tableau Consommation" },
        { "source" => "mise_en_situation", "location" => "distance 186 km" }
      ])
  end

  let!(:classroom_subject) { create(:classroom_subject, classroom: classroom, subject: subject) }

  def visit_question(question)
    visit student_question_path(
      access_code: classroom.access_code,
      subject_id: subject.id,
      id: question.id
    )
  end

  scenario "cliquer 'Voir la correction' affiche la correction sous la question" do
    login_as_student(student, classroom)
    visit_question(q1)

    expect(page).to have_button("Voir la correction")
    click_button "Voir la correction"

    expect(page).to have_content("Car = 56,73 l / Van = 38,68 kWh")
  end

  scenario "la correction affiche le texte, l'explication, les données utiles et les concepts clés" do
    login_as_student(student, classroom)
    visit_question(q1)
    click_button "Voir la correction"

    # Correction text (green section, rendered uppercase via CSS)
    expect(page).to have_content(/correction/i)
    expect(page).to have_content("Car = 56,73 l / Van = 38,68 kWh")

    # Explication pédagogique
    expect(page).to have_content("Explication")
    expect(page).to have_content("On utilise la formule Consommation × Distance / 100")

    # Data hints (source + location)
    expect(page).to have_content("Où trouver les données ?")
    expect(page).to have_content("DT")
    expect(page).to have_content("tableau Consommation")
    expect(page).to have_content("mise_en_situation")
    expect(page).to have_content("distance 186 km")

    # Key concepts (badges)
    expect(page).to have_content("Concepts clés")
    expect(page).to have_content("énergie primaire")
    expect(page).to have_content("rendement")
  end

  scenario "la correction reste visible quand l'élève revient sur la question" do
    login_as_student(student, classroom)
    visit_question(q1)
    click_button "Voir la correction"

    expect(page).to have_content("Car = 56,73 l / Van = 38,68 kWh")

    # Navigate away then come back
    visit_question(q2)
    visit_question(q1)

    # Correction should still be visible (no button, correction displayed)
    expect(page).not_to have_button("Voir la correction")
    expect(page).to have_content("Car = 56,73 l / Van = 38,68 kWh")
  end

  scenario "après révélation, le document DR corrigé apparaît dans la sidebar" do
    login_as_student(student, classroom)
    visit_question(q1)

    # On desktop (1400x900), sidebar is always visible — no hamburger click needed
    within("aside[data-sidebar-target='drawer']") do
      expect(page).not_to have_link("DR corrigé")
    end

    click_button "Voir la correction"

    # Reload the page to get the full sidebar with correction documents
    visit_question(q1)

    within("aside[data-sidebar-target='drawer']") do
      expect(page).to have_link("DR corrigé")
    end
  end

  scenario "le bouton 'Voir la correction' n'apparaît pas si la question n'a pas de réponse" do
    login_as_student(student, classroom)
    visit_question(q2) # q2 has no answer

    expect(page).not_to have_button("Voir la correction")
  end

  scenario "après révélation, la question est marquée comme terminée (✓) dans la sidebar" do
    login_as_student(student, classroom)
    visit_question(q1)

    # On desktop, sidebar is always visible
    # q1 is the current question, so it shows ◉ (current indicator)
    within("aside[data-sidebar-target='drawer']") do
      expect(page).to have_link(text: /◉.*Q1\.1/)
    end

    click_button "Voir la correction"

    # Reload to see updated sidebar
    visit_question(q1)

    # After reveal: question shown with ✓
    within("aside[data-sidebar-target='drawer']") do
      expect(page).to have_link(text: /✓.*Q1\.1/)
    end
  end
end
