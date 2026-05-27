require "rails_helper"

RSpec.describe StripesComponent, type: :component do
  describe "rendering" do
    before { render_inline(described_class.new) }

    it "renders a wrapper div with flex, h-[5px], and flex-shrink-0" do
      expect(page).to have_css("div.flex.h-\\[5px\\].flex-shrink-0")
    end

    it "marks the wrapper as aria-hidden (decorative)" do
      expect(page).to have_css("div[aria-hidden='true']")
    end

    it "renders exactly 4 child stripes" do
      expect(page).to have_css("div.flex.h-\\[5px\\] > div", count: 4)
    end

    it "uses the 4 audience-aware tokens in order: accent-primary, warning, accent-secondary, on-surface" do
      html = page.native.to_html
      idx_primary    = html.index("bg-accent-primary")
      idx_warning    = html.index("bg-warning")
      idx_secondary  = html.index("bg-accent-secondary")
      idx_on_surface = html.index("bg-on-surface")

      expect(idx_primary).not_to be_nil
      expect(idx_warning).not_to be_nil
      expect(idx_secondary).not_to be_nil
      expect(idx_on_surface).not_to be_nil

      expect(idx_primary).to be < idx_warning
      expect(idx_warning).to be < idx_secondary
      expect(idx_secondary).to be < idx_on_surface
    end
  end

  describe "B1 token contract — no dead spec tokens leak in" do
    UNDEFINED_TOKENS = %w[
      accent-warning accent-success accent-danger
      surface-elevated surface-inverse on-inverse
      text-text-primary text-text-muted border-text-primary
    ].freeze

    it "does not reference any undefined B1 token" do
      render_inline(described_class.new)
      html = page.native.to_html
      UNDEFINED_TOKENS.each do |bad|
        expect(html).not_to include(bad), "StripesComponent rendered undefined token '#{bad}' — see B1 contract"
      end
    end
  end
end
