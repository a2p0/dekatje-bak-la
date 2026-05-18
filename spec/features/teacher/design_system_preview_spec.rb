require "rails_helper"

# T019 — verifies the /teacher/design-system/preview demo page renders
# under teacher auth and is gated against anonymous access.
RSpec.describe "Teacher: design system preview page", type: :feature do
  let(:user) { create(:user, confirmed_at: Time.current) }

  def sign_in_teacher(user)
    visit new_user_session_path
    fill_in "Email",    with: user.email
    fill_in "Password", with: "password123"
    click_button "Se connecter"
    expect(page).to have_current_path(teacher_root_path)
  end

  scenario "authenticated teacher sees the preview page" do
    sign_in_teacher(user)
    visit teacher_design_system_preview_path

    expect(page).to have_content("Design system preview")
    # At least the accent-primary probe must be present (used by T020/T020b)
    # Probes are per-audience to avoid ambiguous descendant selectors.
    %w[student teacher public].each do |audience|
      expect(page).to have_css("#probe-accent-primary-#{audience}", visible: :all)
    end
  end

  scenario "anonymous visitor is redirected to login" do
    visit teacher_design_system_preview_path
    expect(page).to have_current_path(new_user_session_path)
  end
end
