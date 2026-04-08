require "rails_helper"

RSpec.describe "Story 8: Configuration clé API élève", type: :feature do
  let(:classroom) { create(:classroom, name: "Terminale SIN 2026") }
  let(:student)   { create(:student, classroom: classroom) }
  let(:subject_record) do
    create(:subject,
      status: :published,
      specific_presentation: "La société CIME fabrique des véhicules électriques.")
  end

  let(:part) do
    create(:part,
      subject: subject_record,
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
      position: 1)
  end

  let!(:answer) do
    create(:answer,
      question: question,
      correction_text: "Car = 56,73 l",
      explanation_text: "Formule Consommation x Distance / 100")
  end

  let!(:classroom_subject) { create(:classroom_subject, classroom: classroom, subject: subject_record) }

  def wait_for_settings_controller
    expect(page).to have_css("[data-settings-connected='true']", wait: 10)
  end

  scenario "l'élève accède aux réglages via le lien dans la liste des sujets" do
    login_as_student(student, classroom)

    click_link "Réglages", match: :first

    expect(page).to have_content("Réglages")
    expect(page).to have_field("Provider")
  end

  scenario "l'élève accède aux réglages depuis la sidebar de la page question" do
    login_as_student(student, classroom)

    visit student_question_path(
      access_code: classroom.access_code,
      subject_id: subject_record.id,
      id: question.id
    )

    # On desktop (1400px), sidebar is visible via lg:translate-x-0
    sidebar = find("aside[data-sidebar-target='drawer']")
    link = sidebar.find_link("Réglages", visible: :all)
    page.execute_script("arguments[0].click()", link)

    expect(page).to have_content("Réglages")
    expect(page).to have_field("Provider")
  end

  scenario "changer le provider met à jour la liste des modèles" do
    login_as_student(student, classroom)
    visit student_settings_path(access_code: classroom.access_code)
    wait_for_settings_controller

    # Switch to anthropic — Stimulus rebuilds the model <select> via JS
    select "Anthropic", from: "Provider"

    # Verify anthropic models appear
    expect(page).to have_css("select[name='student[api_model]'] option", text: "Claude", wait: 5)

    # Switch to openai
    select "Openai", from: "Provider"
    expect(page).to have_css("select[name='student[api_model]'] option", text: "GPT", wait: 5)

    # Switch to google
    select "Google", from: "Provider"
    expect(page).to have_css("select[name='student[api_model]'] option", text: "Gemini", wait: 5)
  end

  scenario "tester une clé API valide affiche un message de succès vert" do
    # Stub external HTTP at network level (mocks don't cross Selenium threads)
    stub_request(:post, /anthropic|openrouter|openai|googleapis/)
      .to_return(status: 200, body: '{"choices":[{"message":{"content":"OK"}}]}', headers: { "Content-Type" => "application/json" })

    login_as_student(student, classroom)
    visit student_settings_path(access_code: classroom.access_code)
    wait_for_settings_controller

    fill_in "Clé API", with: "sk-test-valid-key-123"
    click_button "Tester la clé"

    # Turbo Stream replaces the #test_key_result element asynchronously via JS fetch
    expect(page).to have_css("#test_key_result", text: "Clé valide", wait: 10)
  end

  scenario "tester une clé API invalide affiche un message d'erreur rouge" do
    # Stub external HTTP to return 401 (invalid key)
    stub_request(:post, /anthropic|openrouter|openai|googleapis/)
      .to_return(status: 401, body: '{"error":{"message":"Invalid API key"}}', headers: { "Content-Type" => "application/json" })

    login_as_student(student, classroom)
    visit student_settings_path(access_code: classroom.access_code)
    wait_for_settings_controller

    fill_in "Clé API", with: "sk-invalid-key"
    click_button "Tester la clé"

    # The error from the API call should appear
    expect(page).to have_css("#test_key_result", text: /invalide|Invalid|error/i, wait: 10)
  end

  scenario "enregistrer les réglages sauvegarde et affiche une confirmation" do
    login_as_student(student, classroom)
    visit student_settings_path(access_code: classroom.access_code)

    select "Anthropic", from: "Provider"
    fill_in "Clé API", with: "sk-ant-my-secret-key"
    click_button "Enregistrer"

    expect(page).to have_content("Réglages enregistrés.")

    student.reload
    expect(student.api_provider).to eq("anthropic")
    expect(student.api_key).to eq("sk-ant-my-secret-key")
  end

  scenario "le champ clé API bascule entre masqué et visible au clic sur l'icône oeil" do
    login_as_student(student, classroom)
    visit student_settings_path(access_code: classroom.access_code)
    wait_for_settings_controller

    fill_in "Clé API", with: "sk-secret-key"

    # Initially password type (masked)
    api_key_field = find("[data-settings-target='apiKey']")
    expect(api_key_field[:type]).to eq("password")

    # Click the toggle button (eye icon)
    find("[data-action='click->settings#toggleApiKey']").click

    # Now visible
    expect(page).to have_css("[data-settings-target='apiKey'][type='text']", wait: 5)

    # Click again to mask
    find("[data-action='click->settings#toggleApiKey']").click
    expect(page).to have_css("[data-settings-target='apiKey'][type='password']", wait: 5)
  end

  scenario "sans clé API configurée, le bouton Tutorat invite à configurer les réglages" do
    expect(student.api_key).to be_blank

    login_as_student(student, classroom)
    visit student_question_path(
      access_code: classroom.access_code,
      subject_id: subject_record.id,
      id: question.id
    )

    # Wait for the Stimulus chat controller to actually connect
    expect(page).to have_css("[data-chat-connected='true']", wait: 10)

    # The Tutorat button triggers a native JS confirm() via chat_controller.open()
    accept_confirm do
      click_button "Tutorat"
    end

    expect(page).to have_current_path(student_settings_path(access_code: classroom.access_code), wait: 5)
    expect(page).to have_content("Réglages")
  end
end
