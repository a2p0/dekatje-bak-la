require "rails_helper"

RSpec.describe BottomBarComponent, type: :component do
  it "renders with prev and next links" do
    render_inline(described_class.new(
      prev_href: "/questions/1",
      prev_label: "Q1.1",
      next_href: "/questions/3",
      next_label: "Q1.3"
    ))

    expect(page).to have_link(href: "/questions/1", text: /Q1\.1/)
    expect(page).to have_link(href: "/questions/3", text: /Q1\.3/)
  end

  it "is hidden on desktop (lg:hidden)" do
    render_inline(described_class.new(prev_href: "/", next_href: "/"))

    expect(page).to have_css("div.lg\\:hidden")
  end

  it "renders a center slot (e.g. tutorat button)" do
    render_inline(described_class.new(prev_href: "/a", next_href: "/b")) do |bar|
      bar.with_center { "Tutorat" }
    end

    expect(page).to have_text("Tutorat")
  end

  it "handles missing prev link gracefully" do
    render_inline(described_class.new(next_href: "/next", next_label: "Next"))

    expect(page).to have_link(href: "/next", text: /Next/)
    expect(page).not_to have_link(text: /Précédent/)
  end
end