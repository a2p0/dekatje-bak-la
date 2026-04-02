require "rails_helper"

RSpec.describe "Story 8: Configuration clé API élève", type: :feature do
  let(:classroom) { create(:classroom, name: "Terminale SIN 2026") }
  let(:student)   { create(:student, classroom: classroom) }
  let(:subject_record) do
    create(:subject,
      title: "BAC STI2D Metropole 2025",
      status: :published,
      presentation_text: "La société CIME fabrique des véhicules électriques.")
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

  scenario "l'élève accède aux réglages via le lien dans la liste des sujets" do
    login_as_student(student, classroom)

    click_link "Réglages"

    expect(page).to have_content("Réglages")
    expect(page).to have_field("Provider")
    expect(page).to have_field("Clé API")
  end

  scenario "l'élève accède aux réglages via le lien dans la sidebar de la question", js: true do
    login_as_student(student, classroom)
    visit student_question_path(
      access_code: classroom.access_code,
      subject_id: subject_record.id,
      id: question.id
    )

    within("aside") do
      click_link "Réglages"
    end

    expect(page).to have_content("Réglages")
    expect(page).to have_field("Provider")
  end

  scenario "changer le provider met à jour la liste des modèles", js: true do
    login_as_student(student, classroom)
    visit student_settings_path(access_code: classroom.access_code)

    # Default provider is openrouter (api_provider: 0)
    expect(page).to have_select("student[api_model]")

    # Switch to anthropic
    select "Anthropic", from: "Provider"

    # Verify anthropic models appear
    expect(page).to have_select("student[api_model]", with_options: [ "$ Claude Haiku 4.5" ])
    expect(page).to have_select("student[api_model]", with_options: [ "$$ Claude Sonnet 4.6" ])

    # Switch to openai
    select "Openai", from: "Provider"

    expect(page).to have_select("student[api_model]", with_options: [ "$ GPT-4o Mini" ])
    expect(page).to have_select("student[api_model]", with_options: [ "$$ GPT-4o" ])

    # Switch to google
    select "Google", from: "Provider"

    expect(page).to have_select("student[api_model]", with_options: [ "$ Gemini 2.0 Flash" ])
    expect(page).to have_select("student[api_model]", with_options: [ "$$$ Gemini 2.5 Pro" ])
  end

  scenario "tester une clé API valide affiche un message de succès vert", js: true do
    allow(ValidateStudentApiKey).to receive(:call).and_return({ valid: true })

    login_as_student(student, classroom)
    visit student_settings_path(access_code: classroom.access_code)

    fill_in "Clé API", with: "sk-test-valid-key-123"
    click_button "Tester la clé"

    expect(page).to have_css("#test_key_result", text: "Clé valide")
    expect(page).to have_css("#test_key_result", text: "connexion réussie")
  end

  scenario "tester une clé API invalide affiche un message d'erreur rouge", js: true do
    allow(ValidateStudentApiKey).to receive(:call).and_return({ valid: false, error: "Clé API invalide ou expirée." })

    login_as_student(student, classroom)
    visit student_settings_path(access_code: classroom.access_code)

    fill_in "Clé API", with: "sk-invalid-key"
    click_button "Tester la clé"

    expect(page).to have_css("#test_key_result", text: "Clé API invalide ou expirée.")
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

  scenario "le champ clé API bascule entre masqué et visible au clic sur l'icône oeil", js: true do
    login_as_student(student, classroom)
    visit student_settings_path(access_code: classroom.access_code)

    fill_in "Clé API", with: "sk-secret-key"

    # Initially password type (masked)
    api_key_field = find("[data-settings-target='apiKey']")
    expect(api_key_field[:type]).to eq("password")

    # Click the toggle button (eye icon)
    find("button", text: "\u{1F441}").click

    # Now visible
    expect(api_key_field[:type]).to eq("text")

    # Click again to mask
    find("button", text: "\u{1F441}").click

    expect(api_key_field[:type]).to eq("password")
  end

  scenario "sans clé API configurée, le bouton Tutorat invite à configurer les réglages", js: true do
    # Student has no api_key configured
    expect(student.api_key).to be_blank

    login_as_student(student, classroom)
    visit student_question_path(
      access_code: classroom.access_code,
      subject_id: subject_record.id,
      id: question.id
    )

    # The Tutorat button triggers a JS confirm dialog
    # Accept the confirm to be redirected to settings
    accept_confirm("Vous devez configurer votre cle IA pour utiliser le tutorat. Aller aux reglages ?") do
      click_button "Tutorat"
    end

    expect(page).to have_current_path(student_settings_path(access_code: classroom.access_code))
    expect(page).to have_content("Réglages")
    expect(page).to have_field("Clé API")
  end
end
