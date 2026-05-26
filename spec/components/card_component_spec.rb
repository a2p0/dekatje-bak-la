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
    it "for variant :hero with accent :success, footer border uses the success token (not rad-rule)" do
      render_inline(described_class.new(variant: :hero, accent: :success)) do |card|
        card.with_body { "body" }
        card.with_footer { "footer" }
      end

      footer_classes = page.find("div.border-t", text: "footer")[:class]

      expect(footer_classes).not_to include("border-rad-rule")
      expect(footer_classes).to include("border-success")
    end

    it "for variant :hero with accent :primary, footer border uses accent-primary" do
      render_inline(described_class.new(variant: :hero, accent: :primary)) do |card|
        card.with_body { "body" }
        card.with_footer { "footer" }
      end

      footer_classes = page.find("div.border-t", text: "footer")[:class]

      expect(footer_classes).not_to include("border-rad-rule")
      expect(footer_classes).to include("border-accent-primary")
    end

    it "for variant :default, footer uses semantic border-rule (not rad-rule)" do
      render_inline(described_class.new(variant: :default)) do |card|
        card.with_body { "body" }
        card.with_footer { "footer" }
      end

      footer_classes = page.find("div.border-t", text: "footer")[:class]

      expect(footer_classes).not_to include("border-rad-rule")
      expect(footer_classes).to include("border-rule")
    end
  end

  describe "B1 token contract — only existing semantic tokens are referenced" do
    # Guards against the spec drift discovered during code review:
    # `accent-warning`, `accent-success`, `on-accent` (sans suffixe), `surface-elevated`,
    # `text-primary`, `text-muted`, `surface-inverse`, `on-inverse` n'existent pas en B1.
    # Tokens RÉELS B1 dans app/assets/tailwind/application.css :
    UNDEFINED_TOKENS = %w[
      accent-warning accent-success accent-danger
      bg-surface-elevated surface-inverse on-inverse
      text-text-primary text-text-muted border-text-primary
    ].freeze

    %i[default elevated hero outlined].each do |variant|
      it "variant :#{variant} never references undefined B1 tokens" do
        render_inline(described_class.new(variant: variant, accent: :primary)) do |card|
          card.with_body { "x" }
          card.with_footer { "x" }
        end
        html = page.native.to_html
        UNDEFINED_TOKENS.each do |bad|
          expect(html).not_to include(bad), "Card variant=#{variant} rendered the undefined token '#{bad}' — see B1 contract"
        end
      end
    end
  end
end
