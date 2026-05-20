require "rails_helper"

# T020 — SC-003 — verifies that semantic tokens resolve to the correct
# primitive depending on the active audience.
#
# Strategy: visit the demo page (sole entry under teacher auth) which
# renders 3 wrapper divs (one per audience), each containing probe
# elements. Read computed `backgroundColor` via evaluate_script — NOT
# getPropertyValue('--color-...'), which returns the literal "var(...)"
# string (see research.md Q4).
RSpec.describe "Design tokens: audience mapping (SC-003)", type: :feature, js: true do
  let(:user) { create(:user, confirmed_at: Time.current) }

  before do
    visit new_user_session_path
    fill_in "Email",    with: user.email
    fill_in "Password", with: "password123"
    click_button "Se connecter"
    expect(page).to have_current_path(teacher_root_path)
    visit teacher_design_system_preview_path
    # Layout has class="dark" hardcoded on <html>; remove it to test
    # light-mode mapping (T020). T020b — dark — uses force_dark! instead.
    page.execute_script("document.documentElement.classList.remove('dark')")
    sleep 0.1
  end

  def computed_bg(selector)
    page.evaluate_script(
      "getComputedStyle(document.querySelector(#{selector.to_json})).backgroundColor"
    )
  end

  it "renders accent-primary as balisier-red under student wrapper" do
    expect(computed_bg('#probe-accent-primary-student'))
      .to eq(hex_to_rgb("#d4452e"))
  end

  it "renders accent-primary as sea-teal under teacher wrapper" do
    expect(computed_bg('#probe-accent-primary-teacher'))
      .to eq(hex_to_rgb("#127566"))
  end

  it "renders accent-primary as balisier-red under public wrapper" do
    expect(computed_bg('#probe-accent-primary-public'))
      .to eq(hex_to_rgb("#d4452e"))
  end
end
