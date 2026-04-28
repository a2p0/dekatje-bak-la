require "rails_helper"

RSpec.describe "Story 3: Upload et extraction de sujets PDF", type: :feature do
  let(:user) { create(:user, confirmed_at: Time.current) }

  def login_as(user)
    visit new_user_session_path
    fill_in "Email", with: user.email
    fill_in "Password", with: "password123"
    click_button "Se connecter"
    expect(page).to have_content("Mes classes")
  end

  before do
    login_as(user)
  end

  scenario "le formulaire 'Nouveau sujet' demande uniquement les 2 fichiers PDF" do
    visit new_teacher_subject_path

    expect(page).to have_content("Importer")
    expect(page).to have_field("subject[subject_pdf]")
    expect(page).to have_field("subject[correction_pdf]")
    expect(page).not_to have_field("Titre")
    expect(page).not_to have_select("Spécialité")
  end

  scenario "le sujet est créé et l'extraction démarre quand les 2 PDFs sont importés" do
    visit new_teacher_subject_path

    attach_file "subject[subject_pdf]", Rails.root.join("spec/fixtures/files/fake_subject.pdf").to_s
    attach_file "subject[correction_pdf]", Rails.root.join("spec/fixtures/files/fake_correction.pdf").to_s
    click_button "Importer"

    expect(page).to have_current_path(%r{/teacher/subjects/\d+})
    expect(page).to have_content("Extraction en cours")

    subject = Subject.last
    expect(subject.extraction_job).to be_present
    expect(subject.extraction_job.status).to eq("pending")
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
    part = create(:part, :specific, subject: subject, title: "Étude des transports", number: 1, position: 1)
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

    # Only attach subject_pdf, skip correction_pdf
    attach_file "subject[subject_pdf]", Rails.root.join("spec/fixtures/files/fake_subject.pdf").to_s
    click_button "Importer"

    expect(page).to have_content(/correction pdf|doit être/i)
    expect(Subject.count).to eq(0)
  end
end
