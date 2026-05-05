require "rails_helper"

RSpec.describe "Teacher sees extraction feedback with elapsed time", type: :feature do
  let(:user) { create(:user, confirmed_at: Time.current) }

  scenario "un job en cours affiche le temps écoulé et l'aria-live=polite" do
    subject_record = create(:subject, owner: user)
    job = create(:extraction_job, subject: subject_record, status: :processing)
    job.update_columns(updated_at: 45.seconds.ago)

    login_as(user, scope: :user)
    visit teacher_subject_path(subject_record)

    expect(page).to have_css('#extraction-status[aria-live="polite"]')
    expect(page).to have_css('#extraction-status[aria-atomic="true"]')
    expect(page).to have_content(/démarrée il y a/i)
  end
end
