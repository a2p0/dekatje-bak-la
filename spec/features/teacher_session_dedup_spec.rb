require "rails_helper"

RSpec.describe "US2: Teacher uploads second specialty — dedup common parts", type: :feature do
  let(:user) { create(:user, confirmed_at: Time.current) }
  let!(:exam_session) { create(:exam_session, owner: user, title: "BAC 2024 Polynesie", year: "2024") }

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

  scenario "second specialty upload attaches to existing session via validation form" do
    visit new_teacher_subject_path

    attach_file "subject[subject_pdf]", Rails.root.join("spec/fixtures/files/fake_subject.pdf").to_s
    attach_file "subject[correction_pdf]", Rails.root.join("spec/fixtures/files/fake_correction.pdf").to_s
    click_button "Importer"

    expect(page).to have_current_path(%r{/teacher/subjects/\d+})
    subject_id = page.current_path.split("/").last.to_i
    subject_obj = Subject.find(subject_id)

    raw_json = JSON.generate({
      "metadata" => {
        "title"    => "BAC 2024 Polynesie",
        "year"     => "2024",
        "exam"     => "bac",
        "specialty" => "ac",
        "region"   => "polynesie",
        "variante" => "normale"
      }
    })
    subject_obj.extraction_job.update!(status: :done, raw_json: raw_json)

    visit teacher_subject_path(subject_obj)
    click_link "Valider le sujet"

    expect(page).to have_content("Session existante détectée")
    expect(page).to have_content("BAC 2024 Polynesie")

    choose "Rattacher à la session existante"
    click_button "Valider"
    expect(page).to have_content(/Sujet créé avec succès/i, wait: 5)

    expect(subject_obj.reload.exam_session).to eq(exam_session)
    expect(ExamSession.where(owner: user, title: "BAC 2024 Polynesie").count).to eq(1)
  end
end
