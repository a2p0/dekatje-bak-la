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

  def login_as_student
    visit student_login_path(access_code: classroom.access_code)
    fill_in "Identifiant", with: student.username
    fill_in "Mot de passe", with: "password123"
    click_button "Se connecter"
  end

  def visit_question(question)
    visit student_question_path(
      access_code: classroom.access_code,
      subject_id: subject.id,
      id: question.id
    )
  end

  scenario "la sidebar affiche la mise en situation, l'objectif et les documents" do
    login_as_student
    visit_question(q1)

    expect(page).to have_content("La société CIME fabrique des véhicules électriques.")
    expect(page).to have_content("Comparer les modes de transport en termes d'impact environnemental.")
    expect(page).to have_link("Documents Techniques (DT)")
    expect(page).to have_link("DR vierge")
  end

  scenario "sur desktop la sidebar est visible en permanence", js: true do
    login_as_student
    page.driver.browser.manage.window.resize_to(1400, 900)
    visit_question(q1)

    sidebar = find("[data-sidebar-target='drawer']")
    expect(sidebar).to have_content("Mise en situation")
    expect(sidebar).to have_content("La société CIME fabrique des véhicules électriques.")
  end

  scenario "sur mobile la sidebar s'ouvre via le menu hamburger", js: true do
    login_as_student
    page.driver.browser.manage.window.resize_to(375, 812)
    visit_question(q1)

    # Sidebar drawer should be hidden (translated offscreen) on mobile
    sidebar = find("[data-sidebar-target='drawer']")

    # Click hamburger to open
    find("[data-action='click->sidebar#open']").click

    # After opening, sidebar should contain context
    expect(sidebar).to have_content("Mise en situation")
    expect(sidebar).to have_content("La société CIME fabrique des véhicules électriques.")
  end

  scenario "cliquer Question suivante affiche la question suivante" do
    login_as_student
    visit_question(q1)

    expect(page).to have_content("Calculer la consommation en litres pour 186 km.")

    click_link "Question suivante"

    expect(page).to have_content("Comparer les émissions de CO2 des deux véhicules.")
  end

  scenario "sur la dernière question de la partie, le bouton redirige vers les sujets" do
    login_as_student
    visit_question(q2)

    expect(page).not_to have_link("Question suivante")
    click_link "Retour aux sujets"

    expect(page).to have_content("Mes sujets")
  end

  scenario "cliquer sur une autre question dans la sidebar redirige vers cette question" do
    login_as_student
    visit_question(q1)

    click_link "Q1.2 (3 pts)"

    expect(page).to have_content("Comparer les émissions de CO2 des deux véhicules.")
  end

  scenario "cliquer sur une autre partie redirige vers le subject show" do
    login_as_student
    visit_question(q1)

    click_link(/Analyse fonctionnelle/)

    expect(page).to have_content("Identifier les fonctions du système CIME.")
  end

  scenario "un lien DT s'ouvre dans un nouvel onglet" do
    login_as_student
    visit_question(q1)

    dt_link = find_link("Documents Techniques (DT)")
    expect(dt_link[:target]).to eq("_blank")
  end

  scenario "avant correction, le DR corrigé et les questions corrigées ne sont pas visibles" do
    login_as_student
    visit_question(q1)

    expect(page).to have_link("Documents Techniques (DT)")
    expect(page).to have_link("DR vierge")
    expect(page).not_to have_link("DR corrigé")
    expect(page).not_to have_link("Questions corrigées")
  end
end
