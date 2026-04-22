require "rails_helper"

RSpec.describe ButtonComponent, type: :component do
  it "renders a primary (gradient) button by default" do
    render_inline(described_class.new) { "Continuer" }

    expect(page).to have_button("Continuer")
    # Primary uses the indigo → violet gradient as the vibrant brand CTA
    expect(page).to have_css("button.from-indigo-500")
    expect(page).to have_css("button.to-violet-500")
  end

  it "treats :gradient as an alias of :primary for backwards compatibility" do
    render_inline(described_class.new(variant: :gradient)) { "Go !" }

    expect(page).to have_css("button.from-indigo-500")
    expect(page).to have_css("button.to-violet-500")
  end

  it "renders a success button" do
    render_inline(described_class.new(variant: :success)) { "Commencer" }

    expect(page).to have_button("Commencer")
    expect(page).to have_css("button.bg-emerald-500")
  end

  it "renders a ghost button" do
    render_inline(described_class.new(variant: :ghost)) { "Annuler" }

    expect(page).to have_button("Annuler")
    expect(page).to have_css("button.border")
  end

  it "renders a pill button" do
    render_inline(described_class.new(pill: true)) { "Go" }

    expect(page).to have_css("button.rounded-full")
  end

  it "renders as a link when href is provided" do
    render_inline(described_class.new(href: "/subjects")) { "Voir" }

    expect(page).to have_link("Voir", href: "/subjects")
    expect(page).to have_css("a.from-indigo-500")
  end

  it "renders small size" do
    render_inline(described_class.new(size: :sm)) { "Ok" }

    expect(page).to have_css("button.px-3")
    expect(page).to have_css("button.text-xs")
  end

  it "renders large size" do
    render_inline(described_class.new(size: :lg)) { "Submit" }

    expect(page).to have_css("button.px-6")
    expect(page).to have_css("button.text-base")
  end
end