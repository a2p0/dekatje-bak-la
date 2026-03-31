require "rails_helper"

RSpec.describe NavBarComponent, type: :component do
  it "renders the brand" do
    render_inline(described_class.new) do |nav|
      nav.with_brand { "DekatjeBakLa" }
    end

    expect(page).to have_text("DekatjeBakLa")
    expect(page).to have_css("nav")
  end

  it "renders links" do
    render_inline(described_class.new) do |nav|
      nav.with_brand { "App" }
      nav.with_link(href: "/classes", label: "Mes classes")
      nav.with_link(href: "/sujets", label: "Mes sujets")
    end

    expect(page).to have_link("Mes classes", href: "/classes")
    expect(page).to have_link("Mes sujets", href: "/sujets")
  end

  it "renders actions slot" do
    render_inline(described_class.new) do |nav|
      nav.with_brand { "App" }
      nav.with_actions { "Actions here" }
    end

    expect(page).to have_text("Actions here")
  end
end
