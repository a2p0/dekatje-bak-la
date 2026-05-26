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

  describe "new semantic variants" do
    it ":default renders bg-surface + border-rule" do
      render_inline(described_class.new(variant: :default)) do |c|
        c.with_body { "x" }
      end
      expect(page).to have_css("div.bg-surface.border.border-rule.rounded-2xl")
    end

    it ":elevated renders bg-surface-raised + shadow-sm" do
      render_inline(described_class.new(variant: :elevated)) do |c|
        c.with_body { "x" }
      end
      expect(page).to have_css("div.bg-surface-raised.shadow-sm")
    end

    it ":hero with accent :success renders bg-success + text-on-success" do
      render_inline(described_class.new(variant: :hero, accent: :success)) do |c|
        c.with_body { "x" }
      end
      expect(page).to have_css("div.bg-success.text-on-success.rounded-2xl")
    end

    it ":hero defaults to accent :primary when none provided" do
      render_inline(described_class.new(variant: :hero)) do |c|
        c.with_body { "x" }
      end
      expect(page).to have_css("div.bg-accent-primary.text-on-accent-primary")
    end

    it ":outlined with accent :warning renders border-l-4 + border-warning" do
      render_inline(described_class.new(variant: :outlined, accent: :warning)) do |c|
        c.with_body { "x" }
      end
      expect(page).to have_css("div.bg-transparent.border-l-4.border-warning")
    end

    it ":outlined defaults to accent :primary when none provided" do
      render_inline(described_class.new(variant: :outlined)) do |c|
        c.with_body { "x" }
      end
      expect(page).to have_css("div.border-accent-primary")
    end

    it ":hero with accent :danger renders bg-danger + text-on-danger" do
      render_inline(described_class.new(variant: :hero, accent: :danger)) do |c|
        c.with_body { "x" }
      end
      expect(page).to have_css("div.bg-danger.text-on-danger")
    end
  end

  describe "deprecated legacy variants (pixel-perfect baseline)" do
    it ":rad renders the original bg-rad-paper classes" do
      render_inline(described_class.new(variant: :rad)) do |c|
        c.with_body { "x" }
      end
      expect(page).to have_css("div.bg-rad-paper.border.border-rad-rule.rounded-2xl")
    end

    it ":glow renders the original indigo glow classes" do
      render_inline(described_class.new(variant: :glow)) do |c|
        c.with_body { "x" }
      end
      expect(page).to have_css("div.bg-white.shadow-sm")
      html = page.native.to_html
      expect(html).to include("dark:shadow-[0_0_15px_rgba(99,102,241,0.05)]")
    end

    it "an unknown variant routes to the legacy else branch (bg-white + slate border)" do
      # After Task 3, `:default` is a real semantic variant (bg-surface). The
      # legacy `else` branch is only reached when the variant key is not one
      # of the documented enum values — we verify that path still preserves
      # the pre-B2a pixel-perfect rendering.
      render_inline(described_class.new(variant: :totally_unknown)) do |c|
        c.with_body { "x" }
      end
      expect(page).to have_css("div.bg-white")
      html = page.native.to_html
      expect(html).to include("dark:border-slate-700")
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
