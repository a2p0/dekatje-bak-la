require "rails_helper"

RSpec.describe "Teacher sees extraction feedback with elapsed time", type: :feature do
  let(:user) { create(:user, confirmed_at: Time.current) }

  def sign_in_teacher(user)
    visit new_user_session_path
    fill_in "Email", with: user.email
    fill_in "Password", with: "password123"
    click_button "Se connecter"
  end

  scenario "un job en cours affiche le temps écoulé et l'aria-live=polite" do
    subject_record = create(:subject, owner: user)
    job = create(:extraction_job, subject: subject_record, status: :processing)
    job.update_columns(updated_at: 45.seconds.ago)

    sign_in_teacher(user)
    visit teacher_subject_path(subject_record)

    expect(page).to have_css('#extraction-status[aria-live="polite"]')
    expect(page).to have_css('#extraction-status[aria-atomic="true"]')
    expect(page).to have_content(/démarrée il y a/i)
  end

  scenario "fallback gracieux si updated_at est nil" do
    subject_record = create(:subject, owner: user)
    create(:extraction_job, subject: subject_record, status: :processing)

    allow_any_instance_of(ExtractionJob).to receive(:updated_at).and_return(nil)

    sign_in_teacher(user)
    visit teacher_subject_path(subject_record)

    expect(page).to have_content(/Extraction en cours/i)
    expect(page).not_to have_content(/démarrée il y a/i)
  end
end
