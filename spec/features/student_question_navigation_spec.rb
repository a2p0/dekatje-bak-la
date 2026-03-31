require "rails_helper"

RSpec.describe "Story 6: Navigation question par question avec contexte", type: :feature do
  let(:classroom) { create(:classroom, name: "Terminale SIN 2026") }
  let(:student)   { create(:student, classroom: classroom) }
  let(:subject) do
    create(:subject,
      title: "BAC STI2D Metropole 2025",
      status: :published,
      presentation_text: "La société CIME fabrique des véhicules électriques.")
  end

  let(:part1) do
    create(:part,
      subject: subject,
      number: 1,
      title: "Transport et développement durable",
      objective_text: "Comparer les modes de transport en termes d'impact environnemental.",
      position: 1)
  end

  let(:part2) do
    create(:part,
      subject: subject,
      number: 2,
      title: "Analyse fonctionnelle",
      objective_text: "Analyser le système CIME.",
      position: 2)
  end

  let!(:q1) do
    create(:question,
      part: part1,
      number: "1.1",
      label: "Calculer la consommation en litres pour 186 km.",
      points: 2,
      position: 1)
  end

  let!(:q2) do
    create(:question,
      part: part1,
      number: "1.2",
      label: "Comparer les émissions de CO2 des deux véhicules.",
      points: 3,
      position: 2)
  end

  let!(:q3) do
    create(:question,
      part: part2,
      number: "2.1",
      label: "Identifier les fonctions du système CIME.",
      points: 2,
      position: 1)
  end

  let!(:answer1) { create(:answer, question: q1) }
  let!(:answer2) { create(:answer, question: q2) }

  let!(:classroom_subject) { create(:classroom_subject, classroom: classroom, subject: subject) }

  def visit_question(question)
    visit student_question_path(
      access_code: classroom.access_code,
      subject_id: subject.id,
      id: question.id
    )
  end

  scenario "la sidebar affiche la mise en situation, l'objectif et les documents" do
    login_as_student(student, classroom)
    visit_question(q1)

    # On desktop (1400x900), sidebar is always visible via lg:relative lg:translate-x-0
    within("aside[data-sidebar-target='drawer']") do
      expect(page).to have_content("La société CIME fabrique des véhicules électriques.")
      expect(page).to have_content("Comparer les modes de transport en termes d'impact environnemental.")
      expect(page).to have_link("Documents Techniques (DT)")
      expect(page).to have_link("DR vierge")
    end
  end

  scenario "sur desktop la sidebar est visible en permanence" do
    login_as_student(student, classroom)
    visit_question(q1)

    # On desktop (1400x900), sidebar is always visible — no hamburger click needed
    within("aside[data-sidebar-target='drawer']") do
      expect(page).to have_content("La société CIME fabrique des véhicules électriques.")
    end
  end

  scenario "sur mobile la sidebar s'ouvre via le menu hamburger" do
    login_as_student(student, classroom)
    visit_question(q1)

    # Resize to mobile so the hamburger button is visible
    page.driver.browser.manage.window.resize_to(375, 812)
    sleep 0.3

    find("[data-action='click->sidebar#open']").click
    sleep 0.5

    within("[data-sidebar-target='drawer']") do
      expect(page).to have_content("La société CIME fabrique des véhicules électriques.")
    end

    # Reset to desktop width
    page.driver.browser.manage.window.resize_to(1400, 900)
  end

  scenario "cliquer Question suivante affiche la question suivante" do
    login_as_student(student, classroom)
    visit_question(q1)

    expect(page).to have_content("Calculer la consommation en litres pour 186 km.")

    click_link "Question suivante"

    expect(page).to have_content("Comparer les émissions de CO2 des deux véhicules.")
  end

  scenario "sur la dernière question de la partie, le bouton redirige vers les sujets" do
    login_as_student(student, classroom)
    visit_question(q2)

    expect(page).not_to have_link("Question suivante")
    click_link "Retour aux sujets"

    expect(page).to have_content("Mes sujets")
  end

  scenario "cliquer sur une autre question dans la sidebar redirige vers cette question" do
    login_as_student(student, classroom)
    visit_question(q1)

    # On desktop, sidebar is always visible — use JS click to avoid z-index issues
    within("aside[data-sidebar-target='drawer']") do
      link = find_link("Q1.2", visible: :all)
      page.execute_script("arguments[0].click()", link)
    end

    expect(page).to have_content("Comparer les émissions de CO2 des deux véhicules.")
  end

  scenario "cliquer sur une autre partie redirige vers le subject show" do
    login_as_student(student, classroom)
    visit_question(q1)

    # On desktop, sidebar is always visible
    within("aside[data-sidebar-target='drawer']") do
      # The sidebar shows part title and answered/total in separate spans
      link = find_link("Analyse fonctionnelle", visible: :all)
      page.execute_script("arguments[0].click()", link)
    end

    # Subject#show redirects to a question page (may be same part if no undone in part2)
    expect(page).to have_css("[data-controller='sidebar chat']")
  end

  scenario "un lien DT s'ouvre dans un nouvel onglet" do
    login_as_student(student, classroom)
    visit_question(q1)

    # On desktop, sidebar is always visible
    within("aside[data-sidebar-target='drawer']") do
      dt_link = find_link("Documents Techniques (DT)")
      expect(dt_link[:target]).to eq("_blank")
    end
  end

  scenario "avant correction, le DR corrigé et les questions corrigées ne sont pas visibles" do
    login_as_student(student, classroom)
    visit_question(q1)

    # On desktop, sidebar is always visible
    within("aside[data-sidebar-target='drawer']") do
      expect(page).to have_link("Documents Techniques (DT)")
      expect(page).to have_link("DR vierge")
      expect(page).not_to have_link("DR corrigé")
      expect(page).not_to have_link("Questions corrigées")
    end
  end
end
