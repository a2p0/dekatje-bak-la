require "rails_helper"

RSpec.describe BottomBarComponent, type: :component do
  describe "rendering" do
    it "renders prev link when prev_href is provided" do
      render_inline(described_class.new(prev_href: "/prev", prev_label: "Q1.1"))
      expect(page).to have_link(text: /Q1\.1/, href: "/prev")
    end

    it "renders next link with default :primary variant" do
      render_inline(described_class.new(next_href: "/next", next_label: "Q1.3"))
      expect(page).to have_css("a.text-accent-primary", text: /Q1\.3/)
    end

    it "renders next link with :success variant in success color" do
      render_inline(described_class.new(next_href: "/done", next_label: "Terminer", next_variant: :success))
      expect(page).to have_css("a.text-success", text: /Terminer/)
    end

    it "renders center slot when provided" do
      render_inline(described_class.new) do |bar|
        bar.with_center { '<button>Tutorat</button>'.html_safe }
      end
      expect(page).to have_css("button", text: "Tutorat")
    end

    it "renders default labels when no label given" do
      render_inline(described_class.new(prev_href: "/p", next_href: "/n"))
      expect(page).to have_link(text: /Précédent/)
      expect(page).to have_link(text: /Suivant/)
    end

    it "uses md:hidden breakpoint (not lg:hidden)" do
      render_inline(described_class.new)
      expect(page).to have_css("div.md\\:hidden")
      expect(page).not_to have_css("div.lg\\:hidden")
    end
  end

  describe "B1 token contract" do
    let(:rendered) do
      render_inline(described_class.new(prev_href: "/p", prev_label: "Prev", next_href: "/n", next_label: "Next"))
        .to_html
    end

    it "uses bg-surface and border-rule" do
      expect(rendered).to include("bg-surface")
      expect(rendered).to include("border-rule")
    end

    it "uses on-surface-muted and accent-primary for prev link" do
      expect(rendered).to include("text-on-surface-muted")
      expect(rendered).to include("hover:text-accent-primary")
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

    it "does NOT contain legacy indigo/violet/emerald colors" do
      expect(rendered).not_to include("from-indigo-500")
      expect(rendered).not_to include("to-violet-500")
      expect(rendered).not_to include("indigo-600")
      expect(rendered).not_to include("emerald-600")
      expect(rendered).not_to include("emerald-400")
    end

    it "does NOT contain slate-* legacy classes" do
      expect(rendered).not_to match(/bg-slate-\d{3}/)
      expect(rendered).not_to match(/text-slate-\d{3}/)
      expect(rendered).not_to match(/border-slate-\d{3}/)
    end
  end

  describe ":gradient variant removed" do
    it "renders :gradient as :primary (no legacy gradient classes)" do
      rendered = render_inline(described_class.new(next_href: "/n", next_label: "X", next_variant: :gradient)).to_html
      expect(rendered).not_to include("from-indigo-500")
      expect(rendered).not_to include("bg-clip-text")
    end
  end
end
