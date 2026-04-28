require "rails_helper"

RSpec.describe "Teacher handles partial or failed extraction", type: :feature do
  let(:user) { create(:user, confirmed_at: Time.current) }

  def sign_in_teacher(user)
    visit new_user_session_path
    fill_in "Email", with: user.email
    fill_in "Password", with: "password123"
    click_button "Se connecter"
    expect(page).to have_current_path("/teacher", wait: 5)
  end

  def upload_subject
    visit new_teacher_subject_path
    attach_file "subject[subject_pdf]",    Rails.root.join("spec/fixtures/files/fake_subject.pdf")
    attach_file "subject[correction_pdf]", Rails.root.join("spec/fixtures/files/fake_correction.pdf")
    click_button "Importer"
    expect(page).to have_current_path(%r{/teacher/subjects/\d+})
    subject_id = page.current_path.split("/").last.to_i
    Subject.find(subject_id)
  end

  context "US3 — partial metadata (region nil)" do
    scenario "form shows available fields pre-filled and 'non détecté' for missing region" do
      sign_in_teacher(user)
      subject_record = upload_subject

      raw_json = JSON.generate({
        "metadata" => {
          "title"    => "CIME 2024",
          "year"     => "2024",
          "exam"     => "bac",
          "specialty" => "ac"
          # region intentionally missing
        }
      })
      subject_record.extraction_job.update!(status: :done, raw_json: raw_json)

      visit teacher_subject_path(subject_record)
      click_link "Valider le sujet"

      expect(page).to have_field("subject[title]", with: "CIME 2024")
      expect(page).to have_field("subject[year]",  with: "2024")
      expect(page).to have_content(/Non détecté/i)
    end
  end

  context "US3 — full extraction failure" do
    scenario "form is fully empty with error message when extraction failed" do
      new_user = create(:user, confirmed_at: Time.current)
      visit new_user_session_path
      fill_in "Email", with: new_user.email
      fill_in "Password", with: "password123"
      click_button "Se connecter"
      expect(page).to have_current_path("/teacher", wait: 5)
      subject_record = upload_subject

      subject_record.extraction_job.update!(
        status: :failed,
        error_message: "Claude API timeout",
        raw_json: nil
      )

      visit teacher_subject_path(subject_record)
      click_link "Valider quand même"
      expect(page).to have_current_path(teacher_subject_validation_path(subject_record), wait: 5)

      expect(page).to have_content(/extraction a échoué/i)
      expect(page).to have_content(/Non détecté/i)
      expect(page).to have_field("subject[title]", with: "")
    end
  end
end
