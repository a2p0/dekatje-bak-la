require "rails_helper"

RSpec.describe BadgeComponent, type: :component do
  it "renders an indigo badge" do
    render_inline(described_class.new(color: :indigo, label: "SIN"))

    expect(page).to have_text("SIN")
    expect(page).to have_css("span.text-indigo-300")
  end

  it "renders an emerald badge" do
    render_inline(described_class.new(color: :emerald, label: "2024"))

    expect(page).to have_text("2024")
    expect(page).to have_css("span.text-emerald-300")
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
