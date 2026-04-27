require "rails_helper"

RSpec.describe "Teacher archives a subject from its detail page", type: :feature do
  let(:user) { create(:user, confirmed_at: Time.current) }

  def sign_in_teacher(user)
    visit new_user_session_path
    fill_in "Email", with: user.email
    fill_in "Password", with: "password123"
    click_button "Se connecter"
  end

  # Turbo.config.forms.confirm is overridden with a custom <dialog> in application.js.
  # Wait for the dialog to appear, then click "Confirmer" inside it.
  def click_with_turbo_confirm(button_text)
    click_button button_text
    dialog = find("dialog", wait: 10)
    within(dialog) { click_button "Confirmer" }
  end

  scenario "un sujet archivé disparaît de la liste active" do
    es = create(:exam_session, owner: user, title: "Sujet à archiver")
    subject_record = create(:subject, owner: user, exam_session: es)

    sign_in_teacher(user)
    visit teacher_subject_path(subject_record)

    click_with_turbo_confirm "Archiver le sujet"

    expect(page).to have_current_path(teacher_subjects_path)
    expect(page).to have_content(/archivé/i)

    visit teacher_subjects_path
    expect(page).not_to have_content("Sujet à archiver")
  end
end
