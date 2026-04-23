require "rails_helper"

RSpec.describe "US1: Teacher uploads 2-file subject (new format)", type: :feature do
  include ActiveJob::TestHelper

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

  scenario "teacher uploads subject_pdf and correction_pdf, extraction is launched" do
    visit new_teacher_subject_path

    fill_in "Titre", with: "BAC STI2D Polynesie 2024 CIME"
    fill_in "Année", with: "2024"
    select "Bac", from: "Type d'examen"
    select "SIN", from: "Spécialité"
    select "Polynésie", from: "Région"

    attach_file "subject[subject_pdf]", Rails.root.join("spec/fixtures/files/dummy.pdf").to_s
    attach_file "subject[correction_pdf]", Rails.root.join("spec/fixtures/files/dummy.pdf").to_s

    # Submit via JS to bypass HTML5 required validation in headless Chrome
    page.execute_script("document.querySelector('form').submit()")

    expect(page).to have_content("BAC STI2D Polynesie 2024 CIME")
    expect(page).to have_content("Session")

    subject_obj = Subject.last
    expect(subject_obj.subject_pdf).to be_attached
    expect(subject_obj.correction_pdf).to be_attached
    expect(subject_obj.exam_session).to be_present
    expect(subject_obj.extraction_job).to be_present
  end

  scenario "teacher selects an existing exam session" do
    exam_session = create(:exam_session, owner: user, title: "Session existante 2024")

    visit new_teacher_subject_path

    select "Session existante 2024", from: "Session existante (optionnel)"
    fill_in "Titre", with: "Sujet ITEC"
    fill_in "Année", with: "2024"
    select "Bac", from: "Type d'examen"
    select "ITEC", from: "Spécialité"
    select "Polynésie", from: "Région"

    attach_file "subject[subject_pdf]", Rails.root.join("spec/fixtures/files/dummy.pdf").to_s
    attach_file "subject[correction_pdf]", Rails.root.join("spec/fixtures/files/dummy.pdf").to_s

    page.execute_script("document.querySelector('form').submit()")

    subject_obj = Subject.last
    expect(subject_obj.exam_session).to eq(exam_session)
  end
end
