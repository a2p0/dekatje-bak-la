require "rails_helper"

RSpec.describe "Story 064-US3 (coordination): single overlay active at a time", type: :feature do
  before(:each) do
    page.driver.browser.manage.window.resize_to(1400, 900)
  end

  let(:teacher)   { create(:user, openrouter_api_key: "sk-or-test") }
  let(:classroom) { create(:classroom, owner: teacher, name: "Terminale SIN 2026", tutor_free_mode_enabled: true) }
  let(:student) do
    create(:student, classroom: classroom, api_key: "sk-test", api_provider: :anthropic)
  end
  let(:subject_record) do
    create(:subject, status: :published, owner: teacher,
      specific_presentation: "Société CIME.")
  end
  let(:part) do
    create(:part, :specific, subject: subject_record, number: 1,
      title: "Partie 1", objective_text: "Objectif test.", position: 1)
  end
  let!(:question) do
    create(:question, part: part, number: "1.1",
      label: "Question test.", points: 2, position: 1)
  end
  let!(:answer) { create(:answer, question: question) }
  let!(:classroom_subject) { create(:classroom_subject, classroom: classroom, subject: subject_record) }

  scenario "dispatching overlay:open with name=tibo closes the sidebar if open", js: true do
    login_as_student(student, classroom)
    visit student_question_path(
      access_code: classroom.access_code,
      subject_id: subject_record.id,
      id: question.id
    )

    # Open the sidebar manually via JS
    page.execute_script(<<~JS)
      const sidebar = document.querySelector("[data-sidebar-target='drawer']")
      sidebar.classList.remove("-translate-x-full")
      sidebar.classList.add("translate-x-0")
    JS

    # Dispatch overlay:open with name=tibo — sidebar should close
    page.execute_script(<<~JS)
      window.dispatchEvent(new CustomEvent("overlay:open", { detail: { name: "tibo" } }))
    JS

    sleep 0.2

    sidebar = find("[data-sidebar-target='drawer']", visible: :all)
    expect(sidebar[:class]).to include("-translate-x-full")
  end

  scenario "dispatching overlay:open with name=sidebar closes the tutor drawer if open", js: true do
    login_as_student(student, classroom)
    visit student_question_path(
      access_code: classroom.access_code,
      subject_id: subject_record.id,
      id: question.id
    )

    # Open the chat drawer manually via JS
    page.execute_script(<<~JS)
      const drawer = document.querySelector("[data-chat-drawer-target='drawer']")
      drawer.classList.remove("translate-x-full")
      drawer.classList.add("translate-x-0")
    JS

    # Dispatch overlay:open with name=sidebar — drawer should close
    page.execute_script(<<~JS)
      window.dispatchEvent(new CustomEvent("overlay:open", { detail: { name: "sidebar" } }))
    JS

    sleep 0.2

    drawer = find("[data-chat-drawer-target='drawer']", visible: :all)
    expect(drawer[:class]).to include("translate-x-full")
  end
end
