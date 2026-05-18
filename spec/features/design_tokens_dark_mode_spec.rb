require "rails_helper"

# T020b — SC-006 — verifies dark mode mapping for each audience.
# Forces .dark on <html> via execute_script after page load, then reads
# the resolved backgroundColor of #probe-accent-primary under each
# audience wrapper.
RSpec.describe "Design tokens: dark mode mapping (SC-006)", type: :feature, js: true do
  let(:user) { create(:user, confirmed_at: Time.current) }

  before do
    visit new_user_session_path
    fill_in "Email",    with: user.email
    fill_in "Password", with: "password123"
    click_button "Se connecter"
    expect(page).to have_current_path(teacher_root_path)
    visit teacher_design_system_preview_path
    page.execute_script("document.documentElement.classList.add('dark')")
    sleep 0.1 # let the repaint settle
  end

  def computed_bg(selector)
    page.evaluate_script(
      "getComputedStyle(document.querySelector(#{selector.to_json})).backgroundColor"
    )
  end

  it "renders accent-primary as balisier-red dark under student wrapper" do
    expect(computed_bg('#probe-accent-primary-student'))
      .to eq(hex_to_rgb("#e85a44"))
  end

  it "renders accent-primary as sea-teal dark under teacher wrapper" do
    expect(computed_bg('#probe-accent-primary-teacher'))
      .to eq(hex_to_rgb("#5fc5b8"))
  end

  it "renders accent-primary as balisier-red dark under public wrapper" do
    expect(computed_bg('#probe-accent-primary-public'))
      .to eq(hex_to_rgb("#e85a44"))
  end
end
