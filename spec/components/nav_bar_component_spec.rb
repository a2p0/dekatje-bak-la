require "rails_helper"

RSpec.describe NavBarComponent, type: :component do
  describe "rendering" do
    it "renders brand slot inside accent-primary container" do
      render_inline(described_class.new) do |nav|
        nav.with_brand { "DekatjeBakLa" }
      end
      expect(page).to have_css("nav .text-accent-primary", text: "DekatjeBakLa")
    end

    it "renders links via with_link helper" do
      render_inline(described_class.new) do |nav|
        nav.with_link(href: "/a", label: "Lien A")
        nav.with_link(href: "/b", label: "Lien B")
      end
      expect(page).to have_link("Lien A", href: "/a")
      expect(page).to have_link("Lien B", href: "/b")
    end

    it "renders actions slot in desktop and mobile dropdown" do
      render_inline(described_class.new) do |nav|
        nav.with_actions { '<button>Profil</button>'.html_safe }
      end
      expect(page).to have_css("button", text: "Profil", count: 2)
    end

    it "renders mobile burger button with nav-menu controller" do
      render_inline(described_class.new)
      expect(page).to have_css("nav[data-controller='nav-menu']")
      expect(page).to have_css("button[data-action='click->nav-menu#toggle']")
    end

    it "does NOT respond to with_breadcrumb (slot removed)" do
      component = described_class.new
      expect(component).not_to respond_to(:with_breadcrumb)
    end
  end

  describe "B1 token contract" do
    let(:rendered) do
      render_inline(described_class.new) do |nav|
        nav.with_brand { "Brand" }
        nav.with_link(href: "/x", label: "X")
        nav.with_actions { "actions" }
      end.to_html
    end

    it "uses bg-surface and border-rule" do
      expect(rendered).to include("bg-surface")
      expect(rendered).to include("border-rule")
    end

    it "uses accent-primary for brand color" do
      expect(rendered).to include("text-accent-primary")
    end

    it "uses on-surface-muted for muted text" do
      expect(rendered).to include("text-on-surface-muted")
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

    it "does NOT contain indigo/violet legacy gradient" do
      expect(rendered).not_to include("from-indigo-500")
      expect(rendered).not_to include("to-violet-500")
    end

    it "does NOT contain slate-* dark mode pairs (replaced by tokens)" do
      expect(rendered).not_to match(/bg-slate-\d{3}/)
      expect(rendered).not_to match(/text-slate-\d{3}/)
      expect(rendered).not_to match(/border-slate-\d{3}/)
    end
  end
end
