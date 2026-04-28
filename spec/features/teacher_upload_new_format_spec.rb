require "rails_helper"

RSpec.describe "US1: Teacher uploads 2-file subject (new format)", type: :feature do
  include ActiveJob::TestHelper

  let(:user) { create(:user, confirmed_at: Time.current) }

  def login_as(user)
    visit new_user_session_path
    fill_in "Email", with: user.email
    fill_in "Password", with: "password123"
    click_button "Se connecter"
    expect(page).to have_current_path("/teacher", wait: 5)
  end

  before do
    login_as(user)
  end

  scenario "teacher uploads subject_pdf and correction_pdf, extraction is launched" do
    visit new_teacher_subject_path

    attach_file "subject[subject_pdf]", Rails.root.join("spec/fixtures/files/fake_subject.pdf").to_s
    attach_file "subject[correction_pdf]", Rails.root.join("spec/fixtures/files/fake_correction.pdf").to_s
    click_button "Importer"

    expect(page).to have_current_path(%r{/teacher/subjects/\d+})
    expect(page).to have_content("Extraction en cours")

    subject_obj = Subject.last
    expect(subject_obj.subject_pdf).to be_attached
    expect(subject_obj.correction_pdf).to be_attached
    expect(subject_obj.extraction_job).to be_present
    expect(subject_obj.extraction_job.status).to eq("pending")
  end

  scenario "teacher completes validation form to assign exam session after extraction" do
    visit new_teacher_subject_path

    attach_file "subject[subject_pdf]", Rails.root.join("spec/fixtures/files/fake_subject.pdf").to_s
    attach_file "subject[correction_pdf]", Rails.root.join("spec/fixtures/files/fake_correction.pdf").to_s
    click_button "Importer"

    expect(page).to have_current_path(%r{/teacher/subjects/\d+})
    subject_id = page.current_path.split("/").last.to_i
    subject_obj = Subject.find(subject_id)

    raw_json = JSON.generate({
      "metadata" => {
        "title" => "BAC STI2D Polynésie 2024",
        "year" => "2024",
        "exam" => "bac",
        "specialty" => "sin",
        "region" => "polynesie",
        "variante" => "normale"
      }
    })
    subject_obj.extraction_job.update!(status: :done, raw_json: raw_json)

    visit teacher_subject_path(subject_obj)
    click_link "Valider le sujet"

    expect(page).to have_field("subject[title]", with: "BAC STI2D Polynésie 2024")
    click_button "Valider"
    expect(page).to have_content(/Sujet créé avec succès/i, wait: 5)

    expect(subject_obj.reload.status).to eq("draft")
    expect(subject_obj.reload.exam_session).to be_present
  end
end
