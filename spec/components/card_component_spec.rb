require "rails_helper"

RSpec.describe CardComponent, type: :component do
  it "renders with body content" do
    render_inline(described_class.new) do |card|
      card.with_body { "Hello world" }
    end

    expect(page).to have_text("Hello world")
    expect(page).to have_css("div.rounded-2xl")
    expect(page).to have_css("div.border")
  end

  it "renders header, body, and footer" do
    render_inline(described_class.new) do |card|
      card.with_header { "Title" }
      card.with_body { "Content" }
      card.with_footer { "Footer" }
    end

    expect(page).to have_text("Title")
    expect(page).to have_text("Content")
    expect(page).to have_text("Footer")
    expect(page).to have_css("div.border-t")
  end

  it "renders without footer when not provided" do
    render_inline(described_class.new) do |card|
      card.with_body { "Content only" }
    end

    expect(page).to have_text("Content only")
    expect(page).not_to have_css("div.border-t")
  end

  describe "footer inherits variant tokens (bugfix audit P1 #6)" do
    it "for variant :hero with accent :success, footer border uses accent-success (not rad-rule)" do
      render_inline(described_class.new(variant: :hero, accent: :success)) do |card|
        card.with_body { "body" }
        card.with_footer { "footer" }
      end

      footer_div = page.find("div.border-t", text: "footer")
      footer_classes = footer_div[:class]

      # Le bug actuel : footer rend "border-t border-rad-rule" en dur
      # Cible : il doit utiliser un token cohérent avec la variant hero (ex: accent-success ou un on-accent border)
      expect(footer_classes).not_to include("border-rad-rule")
      expect(footer_classes).to include("border-accent-success").or include("border-on-accent")
    end
  end
end
