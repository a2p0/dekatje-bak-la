require "rails_helper"

RSpec.describe "Teacher attaches subject to existing exam session", type: :feature do
  let(:user) { create(:user, confirmed_at: Time.current) }
  let!(:existing_session) { create(:exam_session, owner: user, title: "CIME 2024", year: "2024") }

  def sign_in_teacher(user)
    visit new_user_session_path
    fill_in "Email", with: user.email
    fill_in "Password", with: "password123"
    click_button "Se connecter"
    expect(page).to have_current_path("/teacher", wait: 5)
  end

  def upload_and_set_extraction_done(raw_json)
    visit new_teacher_subject_path
    attach_file "subject[subject_pdf]",    Rails.root.join("spec/fixtures/files/fake_subject.pdf")
    attach_file "subject[correction_pdf]", Rails.root.join("spec/fixtures/files/fake_correction.pdf")
    click_button "Importer"

    expect(page).to have_current_path(%r{/teacher/subjects/\d+})
    subject_id = page.current_path.split("/").last.to_i
    subject_record = Subject.find(subject_id)
    subject_record.extraction_job.update!(status: :done, raw_json: raw_json)
    visit teacher_subject_path(subject_record)
    subject_record
  end

  let(:matching_raw_json) do
    JSON.generate({
      "metadata" => {
        "title"    => "CIME 2024",
        "year"     => "2024",
        "exam"     => "bac",
        "specialty" => "ac",
        "region"   => "metropole",
        "variante" => "normale"
      }
    })
  end

  context "US2 — attach to existing session" do
    scenario "extraction matches existing session → teacher chooses Rattacher → subject linked" do
      sign_in_teacher(user)
      subject_record = upload_and_set_extraction_done(matching_raw_json)

      click_link "Valider le sujet"

      expect(page).to have_content("Session existante détectée")
      expect(page).to have_content("CIME 2024")

      choose "Rattacher à la session existante"
      click_button "Valider"

      expect(page).to have_current_path(teacher_subject_path(subject_record))
      expect(page).to have_content(/Sujet créé avec succès/i)
      expect(subject_record.reload.exam_session).to eq(existing_session)
      expect(subject_record.reload.status).to eq("draft")
    end
  end

  context "US2 — create new session despite existing one" do
    scenario "extraction matches existing session → teacher chooses Créer nouvelle → new ExamSession created" do
      sign_in_teacher(user)
      subject_record = upload_and_set_extraction_done(matching_raw_json)

      click_link "Valider le sujet"

      expect(page).to have_content("Session existante détectée")

      choose "Créer une nouvelle session"
      click_button "Valider"

      expect(page).to have_current_path(teacher_subject_path(subject_record))
      expect(page).to have_content(/Sujet créé avec succès/i)
      expect(subject_record.reload.exam_session).not_to eq(existing_session)
      expect(subject_record.reload.status).to eq("draft")
      expect(ExamSession.where(owner: user, title: "CIME 2024", year: "2024").count).to eq(2)
    end
  end
end
