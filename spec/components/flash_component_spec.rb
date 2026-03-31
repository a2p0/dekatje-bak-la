require "rails_helper"

RSpec.describe FlashComponent, type: :component do
  it "renders a notice flash" do
    render_inline(described_class.new(type: :notice, message: "Sauvegardé"))

    expect(page).to have_text("Sauvegardé")
    expect(page).to have_css("div.bg-emerald-50")
  end

  it "renders an alert flash" do
    render_inline(described_class.new(type: :alert, message: "Erreur"))

    expect(page).to have_text("Erreur")
    expect(page).to have_css("div.bg-rose-50")
  end

  it "renders nothing when message is blank" do
    render_inline(described_class.new(type: :notice, message: nil))

    expect(page.text).to be_empty
  end
end
