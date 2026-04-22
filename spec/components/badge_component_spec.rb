require "rails_helper"

RSpec.describe BadgeComponent, type: :component do
  it "renders an indigo badge with light and dark variants" do
    render_inline(described_class.new(color: :indigo, label: "SIN"))

    expect(page).to have_text("SIN")
    # Light mode: dark text on light background for contrast
    expect(page).to have_css("span.text-indigo-700")
    # Dark mode: lighter text on tinted background
    expect(page).to have_css("span.dark\\:text-indigo-400")
  end

  it "renders an emerald badge with light and dark variants" do
    render_inline(described_class.new(color: :emerald, label: "2024"))

    expect(page).to have_text("2024")
    expect(page).to have_css("span.text-emerald-700")
    expect(page).to have_css("span.dark\\:text-emerald-400")
  end

  it "renders an amber badge" do
    render_inline(described_class.new(color: :amber, label: "Métropole"))

    expect(page).to have_text("Métropole")
  end

  it "renders a blue badge" do
    render_inline(described_class.new(color: :blue, label: "DT1"))

    expect(page).to have_text("DT1")
  end
end