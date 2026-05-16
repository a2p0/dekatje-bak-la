require "rails_helper"

RSpec.describe "Story 064-US4: Navigation Parties popover en desktop", type: :feature do
  let(:classroom) { create(:classroom, name: "Terminale SIN 2026") }
  let(:student)   { create(:student, classroom: classroom) }
  let(:subject) do
    create(:subject,
      status: :published,
      specific_presentation: "Société CIME — véhicules électriques.")
  end

  let(:part1) do
    create(:part, :specific, subject: subject, number: 1,
      title: "Transport et développement durable", position: 1)
  end
  let(:part2) do
    create(:part, :specific, subject: subject, number: 2,
      title: "Analyse fonctionnelle", position: 2)
  end

  let!(:q1) do
    create(:question, part: part1, number: "1.1",
      label: "Calculer la consommation.", points: 2, position: 1)
  end
  let!(:q2) do
    create(:question, part: part1, number: "1.2",
      label: "Comparer les émissions.", points: 3, position: 2)
  end
  let!(:q3) do
    create(:question, part: part2, number: "2.1",
      label: "Identifier les fonctions.", points: 2, position: 1)
  end

  let!(:answer1) { create(:answer, question: q1) }
  let!(:answer2) { create(:answer, question: q2) }
  let!(:answer3) { create(:answer, question: q3) }

  let!(:classroom_subject) { create(:classroom_subject, classroom: classroom, subject: subject) }

  def visit_question(question)
    visit student_question_path(
      access_code: classroom.access_code,
      subject_id: subject.id,
      id: question.id
    )
  end

  scenario "cliquer 'Parties' dans la navbar ouvre la sidebar en popover", js: true do
    login_as_student(student, classroom)
    visit_question(q1)

    # Sidebar starts closed on desktop too (Feature 064 popover behavior)
    sidebar = find("aside[data-sidebar-target='drawer']", visible: :all)
    expect(sidebar[:class]).to include("-translate-x-full")

    # Click Parties button in the navbar
    find("nav[aria-label='Navigation élève'] button", text: "Parties").click
    sleep 0.3

    # Sidebar is now visible
    sidebar = find("aside[data-sidebar-target='drawer']", visible: :all)
    expect(sidebar[:class]).to include("translate-x-0")
    expect(sidebar[:class]).not_to include("-translate-x-full")
  end

  scenario "la sidebar liste les parties et leurs questions" do
    login_as_student(student, classroom)
    visit_question(q1)

    sidebar = find("aside[data-sidebar-target='drawer']")
    expect(sidebar).to have_link(text: /Q1\.1/, visible: :all)
    expect(sidebar).to have_link(text: /Q1\.2/, visible: :all)
    expect(sidebar).to have_link(text: /Partie 2/, visible: :all)
  end
end
