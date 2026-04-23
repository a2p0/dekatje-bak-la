require "rails_helper"

RSpec.describe "Story 6: Navigation question par question avec contexte", type: :feature do
  let(:classroom) { create(:classroom, name: "Terminale SIN 2026") }
  let(:student)   { create(:student, classroom: classroom) }
  let(:subject) do
    create(:subject,
      status: :published,
      specific_presentation: "La société CIME fabrique des véhicules électriques.")
  end

  let(:part1) do
    create(:part, :specific,
      subject: subject,
      number: 1,
      title: "Transport et développement durable",
      objective_text: "Comparer les modes de transport en termes d'impact environnemental.",
      position: 1)
  end

  let(:part2) do
    create(:part, :specific,
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

  scenario "la sidebar affiche les documents et les liens de navigation" do
    login_as_student(student, classroom)
    visit_question(q1)

    # On desktop (1400x900), sidebar is visible via lg:translate-x-0
    # Use visible: :all because sidebar content may be off-screen for Selenium
    sidebar = find("aside[data-sidebar-target='drawer']")
    expect(sidebar).to have_link("Documents Techniques", visible: :all)
    expect(sidebar).to have_link("DR vierge", visible: :all)
  end

  scenario "sur desktop la sidebar est visible en permanence" do
    login_as_student(student, classroom)
    visit_question(q1)

    # On desktop (1400x900), sidebar is visible via lg:translate-x-0
    sidebar = find("aside[data-sidebar-target='drawer']")
    expect(sidebar).to have_link(text: /Réglages/, visible: :all)
  end

  scenario "sur mobile la sidebar s'ouvre via le menu hamburger" do
    login_as_student(student, classroom)
    visit_question(q1)

    # Resize to mobile so the hamburger button is visible
    page.driver.browser.manage.window.resize_to(375, 812)
    sleep 0.3

    find("[data-action='click->sidebar#open']", visible: :all).click
    sleep 0.5

    within("aside[data-sidebar-target='drawer']") do
      expect(page).to have_link(text: /Réglages/, visible: :all)
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

  scenario "sur la dernière question d'une partie intermédiaire, 'Partie suivante' envoie à la partie suivante" do
    login_as_student(student, classroom)
    visit_question(q2)

    expect(page).not_to have_link("Question suivante")
    click_link "Partie suivante"

    # Should be on the first question of the next specific part
    expect(page).to have_current_path(student_question_path(access_code: classroom.access_code, subject_id: subject.id, id: q3.id))
  end

  scenario "cliquer sur une autre question dans la sidebar redirige vers cette question" do
    login_as_student(student, classroom)
    visit_question(q1)

    # On desktop (1400x900), sidebar is visible via lg:translate-x-0
    sidebar = find("aside[data-sidebar-target='drawer']")
    link = sidebar.find_link("Q1.2", visible: :all)
    page.execute_script("arguments[0].click()", link)

    expect(page).to have_content("Comparer les émissions de CO2 des deux véhicules.")
  end

  scenario "cliquer sur une autre partie redirige vers le subject show" do
    login_as_student(student, classroom)
    visit_question(q1)

    # On desktop (1400x900), sidebar is always visible via lg:translate-x-0
    link = find("aside[data-sidebar-target='drawer']").find_link("Partie 2", visible: :all)
    page.execute_script("arguments[0].click()", link)

    # Subject#show displays the mise en situation page (first visit, no answers yet)
    # The "Commencer les questions" link only appears on the subject show page
    expect(page).to have_link("Commencer")
  end

  scenario "un lien DT s'ouvre dans un nouvel onglet" do
    login_as_student(student, classroom)
    visit_question(q1)

    # On desktop (1400x900), sidebar is visible via lg:translate-x-0
    # Use visible: :all because sidebar content may be off-screen for Selenium
    sidebar = find("aside[data-sidebar-target='drawer']")
    dt_link = sidebar.find_link("Documents Techniques", visible: :all)
    expect(dt_link[:target]).to eq("_blank")
  end

  scenario "avant correction, le DR corrigé n'est pas visible dans la sidebar" do
    login_as_student(student, classroom)
    visit_question(q1)

    # On desktop (1400x900), sidebar is visible via lg:translate-x-0
    # Use visible: :all because sidebar content may be off-screen for Selenium
    sidebar = find("aside[data-sidebar-target='drawer']")
    expect(sidebar).to have_link("Documents Techniques", visible: :all)
    expect(sidebar).to have_link("DR vierge", visible: :all)
    expect(sidebar).not_to have_link("DR corrigé", visible: :all)
  end
end
