require "rails_helper"

RSpec.describe DataHintsComponent, type: :component do
  let(:data_hints) do
    [
      { "source" => "DT1", "location" => "tableau, ligne Consommation moyenne" },
      { "source" => "mise_en_situation", "location" => "distances Troyes-Le Bourget" }
    ]
  end

  it "renders the section title" do
    render_inline(described_class.new(data_hints: data_hints))
    expect(page).to have_text("Les données nécessaires se trouvaient dans")
  end

  it "renders each source in bold" do
    render_inline(described_class.new(data_hints: data_hints))
    expect(page).to have_css("strong", text: "DT1")
    expect(page).to have_css("strong", text: "mise_en_situation")
  end

  it "renders each location" do
    render_inline(described_class.new(data_hints: data_hints))
    expect(page).to have_text("tableau, ligne Consommation moyenne")
    expect(page).to have_text("distances Troyes-Le Bourget")
  end

  it "renders as a list" do
    render_inline(described_class.new(data_hints: data_hints))
    expect(page).to have_css("ul li", count: 2)
  end

  it "wraps everything in a .data-hints-card div" do
    render_inline(described_class.new(data_hints: data_hints))
    expect(page).to have_css("div.data-hints-card")
  end

  it "renders nothing when data_hints is empty" do
    render_inline(described_class.new(data_hints: []))
    expect(page).not_to have_text("Les données nécessaires")
  end
end