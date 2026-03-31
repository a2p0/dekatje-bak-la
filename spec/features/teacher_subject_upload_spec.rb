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

  def attach_pdf(field_id)
    attach_file field_id, Rails.root.join("spec/fixtures/files/dummy.pdf").to_s
  end

  before do
    login_as(user)
  end

  scenario "le formulaire 'Nouveau sujet' demande titre, année, type, spécialité, région et 5 fichiers PDF" do
    visit new_teacher_subject_path

    expect(page).to have_content("Nouveau sujet")
    expect(page).to have_field("Titre")
    expect(page).to have_field("Année")
    expect(page).to have_select("Type d'examen")
    expect(page).to have_select("Spécialité")
    expect(page).to have_select("Région")
    expect(page).to have_field("Énoncé du sujet (PDF, max 20 MB)")
    expect(page).to have_field("Documents Techniques — DT (PDF, max 20 MB)")
    expect(page).to have_field("Document Réponse vierge — DR (PDF, max 20 MB)")
    expect(page).to have_field("Document Réponse corrigé (PDF, max 20 MB)")
    expect(page).to have_field("Questions corrigées (PDF, max 20 MB)")
  end

  scenario "le sujet est créé et l'extraction démarre quand le formulaire est soumis avec tous les PDFs" do
    visit new_teacher_subject_path

    fill_in "Titre", with: "BAC STI2D Métropole 2026"
    fill_in "Année", with: "2026"
    select "Bac", from: "Type d'examen"
    select "SIN", from: "Spécialité"
    select "Métropole", from: "Région"

    attach_pdf "subject_enonce_file"
    attach_pdf "subject_dt_file"
    attach_pdf "subject_dr_vierge_file"
    attach_pdf "subject_dr_corrige_file"
    attach_pdf "subject_questions_corrigees_file"

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

    expect(page).to have_content("Extraction en cours...")
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

    # Attach only 4 out of 5 PDFs (missing questions_corrigees_file)
    attach_pdf "subject_enonce_file"
    attach_pdf "subject_dt_file"
    attach_pdf "subject_dr_vierge_file"
    attach_pdf "subject_dr_corrige_file"

    # The browser's HTML5 required validation prevents submission when a file is missing.
    # Remove the required attribute to let the server-side validation handle it.
    page.execute_script("document.getElementById('subject_questions_corrigees_file').removeAttribute('required')")

    click_button "Créer le sujet"

    expect(page).to have_content("blank")
    expect(Subject.count).to eq(0)
  end
end
