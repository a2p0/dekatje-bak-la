require "rails_helper"

RSpec.describe BreadcrumbComponent, type: :component do
  it "renders nothing when items is empty" do
    render_inline(described_class.new(items: []))
    expect(page).not_to have_css("nav")
  end

  it "renders a breadcrumb with multiple items" do
    render_inline(described_class.new(items: [
      { label: "Mes sujets", href: "/sujets" },
      { label: "BAC 2024", href: "/sujets/1" },
      { label: "Q1.2" }
    ]))

    expect(page).to have_css("nav[aria-label='Fil d\\'Ariane']")
    expect(page).to have_link("Mes sujets", href: "/sujets")
    expect(page).to have_link("BAC 2024", href: "/sujets/1")
    expect(page).to have_text("Q1.2")
  end

  it "marks the last item with aria-current=page" do
    render_inline(described_class.new(items: [
      { label: "Home", href: "/" },
      { label: "Current page" }
    ]))

    expect(page).to have_css("span[aria-current='page']", text: "Current page")
  end

  it "does not link the last item even if href is provided" do
    render_inline(described_class.new(items: [
      { label: "Step 1", href: "/1" },
      { label: "Step 2", href: "/2" }
    ]))

    expect(page).to have_link("Step 1", href: "/1")
    expect(page).not_to have_link("Step 2")
    expect(page).to have_css("span[aria-current='page']", text: "Step 2")
  end
end
