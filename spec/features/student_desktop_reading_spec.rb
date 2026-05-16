require "rails_helper"

RSpec.describe "Story 064-US1: Lecture question en desktop", type: :feature do
  let(:teacher)   { create(:user, openrouter_api_key: "sk-or-test") }
  let(:classroom) { create(:classroom, owner: teacher, name: "Terminale SIN 2026", tutor_free_mode_enabled: true) }
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

  let!(:question_with_dt) do
    create(:question,
      part: part,
      number: "1.1",
      label: "Calculer la consommation en litres pour 186 km.",
      points: 2,
      position: 1,
      dt_references: [ "DT1", "DT2" ])
  end

  let!(:question_without_dt) do
    create(:question,
      part: part,
      number: "1.2",
      label: "Question sans document technique.",
      points: 1,
      position: 2,
      dt_references: [])
  end

  let!(:classroom_subject) { create(:classroom_subject, classroom: classroom, subject: subject) }

  def visit_question(question)
    visit student_question_path(
      access_code: classroom.access_code,
      subject_id: subject.id,
      id: question.id
    )
  end

  scenario "la navbar desktop est visible avec logo, tabs, Parties, Tibo et avatar" do
    login_as_student(student, classroom)
    visit_question(question_with_dt)

    nav = find("nav[aria-label='Navigation élève']", visible: :all)
    expect(nav).to have_text("DekatjeBakLa")
    expect(nav).to have_button("Parties", visible: :all)
    expect(nav).to have_button("Tibo", visible: :all)
  end

  scenario "le breadcrumb desktop affiche Sujet › Partie › Question" do
    login_as_student(student, classroom)
    visit_question(question_with_dt)

    breadcrumb = find("[data-064-breadcrumb]", visible: :all)
    expect(breadcrumb).to have_text("Partie 1")
    expect(breadcrumb).to have_text("Q1.1")
  end

  scenario "la colonne droite affiche un viewer DT avec iframe et bandeau références" do
    login_as_student(student, classroom)
    visit_question(question_with_dt)

    dt_viewer = find("aside[aria-label='Document technique']", visible: :all)
    expect(dt_viewer).to have_selector("iframe[title*='Document Technique']", visible: :all)
    expect(dt_viewer).to have_text("DT1")
    expect(dt_viewer).to have_text("DT2")
  end

  scenario "sans dt_references, la colonne droite affiche un état neutre" do
    login_as_student(student, classroom)
    visit_question(question_without_dt)

    dt_viewer = find("aside[aria-label='Document technique']", visible: :all)
    expect(dt_viewer).to have_text("Aucun document technique")
    expect(dt_viewer).not_to have_selector("iframe", visible: :all)
  end
end
