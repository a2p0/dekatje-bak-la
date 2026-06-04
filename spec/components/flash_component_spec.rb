require "rails_helper"

RSpec.describe FlashComponent, type: :component do
  describe "rendering" do
    it "renders a notice flash in success colors" do
      render_inline(described_class.new(type: :notice, message: "Sauvegardé"))
      expect(page).to have_text("Sauvegardé")
      expect(page).to have_css("div.text-success")
      expect(page).to have_css("div.bg-success\\/10")
    end

    it "renders an alert flash in danger colors" do
      render_inline(described_class.new(type: :alert, message: "Erreur"))
      expect(page).to have_text("Erreur")
      expect(page).to have_css("div.text-danger")
      expect(page).to have_css("div.bg-danger\\/10")
    end

    it "renders nothing when message is blank" do
      render_inline(described_class.new(type: :notice, message: nil))
      expect(page.text).to be_empty
    end

    it "renders nothing when message is empty string" do
      render_inline(described_class.new(type: :alert, message: ""))
      expect(page.text).to be_empty
    end

    it "renders a dismiss button wired to dismissable controller" do
      render_inline(described_class.new(type: :notice, message: "msg"))
      expect(page).to have_css("[data-controller='dismissable']")
      expect(page).to have_css("button[aria-label='Fermer'][data-action='click->dismissable#dismiss']")
    end
  end

  describe "B1 token contract" do
    let(:rendered_notice) { render_inline(described_class.new(type: :notice, message: "X")).to_html }
    let(:rendered_alert)  { render_inline(described_class.new(type: :alert,  message: "X")).to_html }

    it "notice uses success tokens (not emerald)" do
      expect(rendered_notice).to include("bg-success/10")
      expect(rendered_notice).to include("text-success")
      expect(rendered_notice).to include("border-success/20")
    end

    it "alert uses danger tokens (not rose)" do
      expect(rendered_alert).to include("bg-danger/10")
      expect(rendered_alert).to include("text-danger")
      expect(rendered_alert).to include("border-danger/20")
    end

    %w[
      accent-warning accent-success accent-danger on-accent
      surface-elevated surface-inverse on-inverse
      text-text-primary text-text-muted
    ].each do |token|
      it "does NOT use undefined token `#{token}` (notice)" do
        expect(rendered_notice).not_to include(token)
      end
    end

    it "does NOT contain legacy emerald-* / rose-* / slate-* classes" do
      [ rendered_notice, rendered_alert ].each do |html|
        expect(html).not_to match(/emerald-\d{3}/)
        expect(html).not_to match(/rose-\d{3}/)
        expect(html).not_to match(/bg-slate-\d{3}/)
        expect(html).not_to match(/text-slate-\d{3}/)
        expect(html).not_to match(/border-slate-\d{3}/)
      end
    end

    it "does NOT contain dark: mode pairs (tokens already theme-aware)" do
      [ rendered_notice, rendered_alert ].each do |html|
        expect(html).not_to match(/dark:bg-/)
        expect(html).not_to match(/dark:text-/)
        expect(html).not_to match(/dark:border-/)
      end
    end
  end
end
