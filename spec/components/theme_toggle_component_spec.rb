require "rails_helper"

RSpec.describe ThemeToggleComponent, type: :component do
  it "renders a toggle button" do
    render_inline(described_class.new)

    expect(page).to have_css("button[data-action='click->theme#toggle']")
    expect(page).to have_css("button[aria-label]")
  end
end