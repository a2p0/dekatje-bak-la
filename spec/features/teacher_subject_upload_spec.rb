require "rails_helper"

RSpec.describe "Story 3: Upload et extraction de sujets PDF", type: :feature do
  let(:user) { create(:user, confirmed_at: Time.current) }

  def login_as(user)
    visit new_user_session_path
    fill_in "Email", with: user.email
    fill_in "Password", with: "password123"
    click_button "Log in"
    expect(page).to have_content("Mes classes")
  end

  before do
    login_as(user)
  end

  scenario "le formulaire 'Nouveau sujet' demande titre, année, type, spécialité, région et 2 fichiers PDF" do
    visit new_teacher_subject_path

    expect(page).to have_content("Nouveau sujet")
    expect(page).to have_field("Titre")
    expect(page).to have_field("Année")
    expect(page).to have_select("Type d'examen")
    expect(page).to have_select("Spécialité")
    expect(page).to have_select("Région")
    expect(page).to have_field("Sujet complet (PDF)")
    expect(page).to have_field("Corrigé complet (PDF)")
  end

  scenario "le sujet est créé et l'extraction démarre quand le formulaire est soumis avec les 2 PDFs" do
    visit new_teacher_subject_path

    fill_in "Titre", with: "BAC STI2D Métropole 2026"
    fill_in "Année", with: "2026"
    select "Bac", from: "Type d'examen"
    select "SIN", from: "Spécialité"
    select "Métropole", from: "Région"

    attach_file "subject[subject_pdf]", Rails.root.join("spec/fixtures/files/dummy.pdf").to_s
    attach_file "subject[correction_pdf]", Rails.root.join("spec/fixtures/files/dummy.pdf").to_s

    # Submit the form via JavaScript to bypass HTML5 validation
    page.execute_script("document.querySelector('form').submit()")

    expect(page).to have_content("Sujet créé")
    expect(page).to have_content("extraction")

    subject = Subject.last
    expect(subject.title).to eq("BAC STI2D Métropole 2026")
    expect(subject.extraction_job).to be_present
    expect(subject.extraction_job.status).to eq("pending")
    expect(ActiveJob::Base.queue_adapter.enqueued_jobs.size).to be >= 1
  end

  scenario "l'enseignant voit 'Extraction en cours...' quand l'extraction est en cours" do
    subject = create(:subject, owner: user)
    create(:extraction_job, subject: subject, status: :processing)

    visit teacher_subject_path(subject)

    expect(page).to have_content("Extraction en cours…")
  end

  scenario "l'enseignant voit les parties et questions extraites quand l'extraction est terminée" do
    subject = create(:subject, owner: user)
    create(:extraction_job, subject: subject, status: :done)
    part = create(:part, subject: subject, title: "Étude des transports", number: 1, position: 1)
    create(:question, part: part, number: "1.1", label: "Calculer la consommation")

    visit teacher_subject_path(subject)

    expect(page).to have_content("done")
    expect(page).to have_content("Valider par partie")
    expect(page).to have_content("Étude des transports")
  end

  scenario "l'enseignant voit le message d'erreur et un bouton 'Relancer' quand l'extraction a échoué" do
    subject = create(:subject, owner: user)
    create(:extraction_job, subject: subject, status: :failed, error_message: "API timeout after 30s")

    visit teacher_subject_path(subject)

    expect(page).to have_content("Erreur")
    expect(page).to have_content("API timeout after 30s")
    expect(page).to have_button("Relancer l'extraction")
  end

  scenario "le formulaire affiche une erreur quand un fichier PDF manque" do
    visit new_teacher_subject_path

    fill_in "Titre", with: "BAC STI2D Métropole 2026"
    fill_in "Année", with: "2026"
    select "Bac", from: "Type d'examen"
    select "SIN", from: "Spécialité"
    select "Métropole", from: "Région"

    # Only attach subject_pdf, skip correction_pdf
    attach_file "subject[subject_pdf]", Rails.root.join("spec/fixtures/files/dummy.pdf").to_s

    # Remove required attributes and submit via JS to avoid Selenium timing issues
    page.execute_script("document.querySelectorAll('input[required]').forEach(el => el.removeAttribute('required'))")
    page.execute_script("document.querySelector('form').submit()")

    expect(page).to have_content("blank")
    expect(Subject.count).to eq(0)
  end
end
