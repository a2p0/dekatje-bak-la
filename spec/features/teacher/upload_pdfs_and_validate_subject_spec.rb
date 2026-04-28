require "rails_helper"

RSpec.describe "Teacher uploads PDFs and validates subject", type: :feature do
  let(:user) { create(:user, confirmed_at: Time.current) }

  def sign_in_teacher(user)
    visit new_user_session_path
    fill_in "Email", with: user.email
    fill_in "Password", with: "password123"
    click_button "Se connecter"
    expect(page).to have_current_path("/teacher", wait: 5)
  end

  context "US1 — nominal upload → extraction done → validation → draft" do
    scenario "teacher uploads 2 PDFs, sees extraction status, validates, subject becomes draft" do
      sign_in_teacher(user)
      visit new_teacher_subject_path

      attach_file "subject[subject_pdf]", Rails.root.join("spec/fixtures/files/fake_subject.pdf")
      attach_file "subject[correction_pdf]", Rails.root.join("spec/fixtures/files/fake_correction.pdf")
      click_button "Importer"

      expect(page).to have_current_path(%r{/teacher/subjects/\d+})
      expect(page).to have_content(/Extraction en cours|En cours d'extraction/i)

      subject_record = Subject.last
      expect(subject_record.status).to eq("uploading")

      raw_json = JSON.generate({
        "metadata" => {
          "title"    => "CIME 2024",
          "year"     => "2024",
          "exam"     => "bac",
          "specialty" => "ac",
          "region"   => "metropole",
          "variante" => "normale"
        }
      })
      subject_record.extraction_job.update!(status: :done, raw_json: raw_json)

      visit teacher_subject_path(subject_record)

      expect(page).to have_link("Valider le sujet")
      click_link "Valider le sujet"

      expect(page).to have_current_path(teacher_subject_validation_path(subject_record))
      expect(page).to have_field("subject[title]", with: "CIME 2024")
      expect(page).to have_field("subject[year]", with: "2024")
      expect(page).to have_select("subject[specialty]", selected: "AC")

      click_button "Valider"

      expect(page).to have_current_path(teacher_subject_path(subject_record))
      expect(page).to have_content(/Sujet créé avec succès/i)
      expect(subject_record.reload.status).to eq("draft")
      expect(subject_record.reload.specialty).to eq("AC")
    end
  end

  context "US1 edge case — single PDF upload rejected" do
    scenario "shows error when correction_pdf is missing" do
      sign_in_teacher(user)
      visit new_teacher_subject_path

      attach_file "subject[subject_pdf]", Rails.root.join("spec/fixtures/files/fake_subject.pdf")
      click_button "Importer"

      expect(page).to have_content(/correction/i)
      expect(Subject.where(status: :uploading).count).to eq(0)
    end
  end
end
