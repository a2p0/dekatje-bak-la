require "rails_helper"

RSpec.describe ModalComponent, type: :component do
  describe "rendering" do
    it "renders dialog with title and aria attributes" do
      render_inline(described_class.new(title: "Confirmer")) do |modal|
        modal.with_body { "Êtes-vous sûr ?" }
      end
      expect(page).to have_css("[role='dialog'][aria-modal='true']")
      expect(page).to have_css("h3", text: "Confirmer")
      expect(page).to have_text("Êtes-vous sûr ?")
    end

    it "uses provided title_id" do
      render_inline(described_class.new(title: "T", title_id: "my-modal"))
      expect(page).to have_css("[aria-labelledby='my-modal']")
      expect(page).to have_css("h3#my-modal")
    end

    it "generates a unique title_id when none given" do
      render_inline(described_class.new(title: "T"))
      expect(page).to have_css("h3[id^='modal-title-']")
    end

    it "renders close button with aria-label" do
      render_inline(described_class.new(title: "T"))
      expect(page).to have_css("button[aria-label='Fermer']")
    end

    it "wires Stimulus modal + focus-trap controllers" do
      render_inline(described_class.new(title: "T"))
      expect(page).to have_css("[data-controller='modal focus-trap']")
      expect(page).to have_css("[data-action='focus-trap:close->modal#close']")
    end

    it "renders backdrop with click-to-close action" do
      render_inline(described_class.new(title: "T"))
      expect(page).to have_css("div.bg-black\\/50[data-action='click->modal#close']")
    end
  end

  describe "B1 token contract" do
    let(:rendered) do
      render_inline(described_class.new(title: "T")) do |modal|
        modal.with_body { "body" }
      end.to_html
    end

    it "uses bg-surface-raised and border-rule on the panel" do
      expect(rendered).to include("bg-surface-raised")
      expect(rendered).to include("border-rule")
    end

    it "uses text-on-surface for title and text-on-surface-muted for close button" do
      expect(rendered).to include("text-on-surface")
      expect(rendered).to include("text-on-surface-muted")
    end

    it "keeps bg-black/50 hardcoded for backdrop (theme-neutral)" do
      expect(rendered).to include("bg-black/50")
    end

    %w[
      accent-warning accent-success accent-danger on-accent
      surface-elevated surface-inverse on-inverse
      text-text-primary text-text-muted
    ].each do |token|
      it "does NOT use undefined token `#{token}`" do
        expect(rendered).not_to include(token)
      end
    end

    it "does NOT contain legacy slate-* / indigo-* dark mode pairs" do
      expect(rendered).not_to match(/bg-slate-\d{3}/)
      expect(rendered).not_to match(/text-slate-\d{3}/)
      expect(rendered).not_to match(/border-slate-\d{3}/)
      expect(rendered).not_to include("border-indigo-500/15")
      expect(rendered).not_to include("rgba(99,102,241")
    end
  end
end
