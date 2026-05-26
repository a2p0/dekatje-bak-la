require "rails_helper"

RSpec.describe ButtonComponent, type: :component do
  it "renders a primary (gradient) button by default" do
    render_inline(described_class.new) { "Continuer" }

    expect(page).to have_button("Continuer")
    # Primary uses the indigo → violet gradient as the vibrant brand CTA
    expect(page).to have_css("button.from-indigo-500")
    expect(page).to have_css("button.to-violet-500")
  end

  it "treats :gradient as an alias of :primary for backwards compatibility" do
    render_inline(described_class.new(variant: :gradient)) { "Go !" }

    expect(page).to have_css("button.from-indigo-500")
    expect(page).to have_css("button.to-violet-500")
  end

  it "renders a success button" do
    render_inline(described_class.new(variant: :success)) { "Commencer" }

    expect(page).to have_button("Commencer")
    expect(page).to have_css("button.bg-emerald-500")
  end

  it "renders a ghost button" do
    render_inline(described_class.new(variant: :ghost)) { "Annuler" }

    expect(page).to have_button("Annuler")
    expect(page).to have_css("button.border")
  end

  it "renders a pill button" do
    render_inline(described_class.new(pill: true)) { "Go" }

    expect(page).to have_css("button.rounded-full")
  end

  it "renders as a link when href is provided" do
    render_inline(described_class.new(href: "/subjects")) { "Voir" }

    expect(page).to have_link("Voir", href: "/subjects")
    expect(page).to have_css("a.from-indigo-500")
  end

  it "renders small size" do
    render_inline(described_class.new(size: :sm)) { "Ok" }

    expect(page).to have_css("button.px-3")
    expect(page).to have_css("button.text-xs")
  end

  it "renders large size" do
    render_inline(described_class.new(size: :lg)) { "Submit" }

    expect(page).to have_css("button.px-6")
    expect(page).to have_css("button.text-base")
  end

  describe "new semantic variants" do
    it ":rad_primary renders bg-accent-primary + text-on-accent-primary" do
      render_inline(described_class.new(variant: :rad_primary))
      expect(page).to have_css("button.bg-accent-primary.text-on-accent-primary")
    end

    it ":secondary renders bg-transparent + border + text-on-surface" do
      render_inline(described_class.new(variant: :secondary))
      expect(page).to have_css("button.bg-transparent.border.border-on-surface.text-on-surface")
    end

    it ":rad_ghost renders bg-transparent + text-on-surface-muted" do
      render_inline(described_class.new(variant: :rad_ghost))
      expect(page).to have_css("button.bg-transparent.text-on-surface-muted")
    end

    it ":danger renders bg-danger + text-on-danger" do
      render_inline(described_class.new(variant: :danger))
      expect(page).to have_css("button.bg-danger.text-on-danger")
    end

    it ":ink renders bg-on-surface + text-surface" do
      render_inline(described_class.new(variant: :ink))
      expect(page).to have_css("button.bg-on-surface.text-surface")
    end
  end

  describe "deprecated legacy variants (pixel-perfect baseline — SC-2 strict)" do
    it ":primary preserves the original indigo gradient classes (22 call sites)" do
      render_inline(described_class.new(variant: :primary))
      html = page.native.to_html
      expect(html).to include("from-indigo-500")
      expect(html).to include("to-violet-500")
      expect(html).to include("shadow-[0_0_16px_rgba(99,102,241,0.3)]")
    end

    it ":gradient is an alias of :primary (same indigo gradient classes)" do
      render_inline(described_class.new(variant: :gradient))
      html = page.native.to_html
      expect(html).to include("from-indigo-500")
      expect(html).to include("to-violet-500")
    end

    it ":success preserves the original emerald classes" do
      render_inline(described_class.new(variant: :success))
      expect(page).to have_css("button.bg-emerald-500.text-white")
    end

    it ":ghost preserves the original outline slate classes (13 call sites)" do
      render_inline(described_class.new(variant: :ghost))
      expect(page).to have_css("button.border.border-slate-200.text-slate-700")
    end
  end

  describe "states" do
    it "disabled: true adds aria-disabled and opacity-60" do
      render_inline(described_class.new(variant: :rad_primary, disabled: true))
      expect(page).to have_css("button[aria-disabled='true']")
      expect(page.native.to_html).to include("opacity-60")
    end

    it "loading: true adds aria-busy + a spinner span" do
      render_inline(described_class.new(variant: :rad_primary, loading: true)) { "Submit" }
      expect(page).to have_css("button[aria-busy='true']")
      expect(page).to have_css("button span.animate-spin", visible: :all)
    end

    it "focus-visible ring uses accent-secondary + offset-2 on new semantic variants" do
      render_inline(described_class.new(variant: :rad_primary))
      html = page.native.to_html
      expect(html).to include("focus-visible:ring-accent-secondary")
      expect(html).to include("focus-visible:ring-offset-2")
    end
  end

  describe "structural props" do
    it ":href renders an <a> element" do
      render_inline(described_class.new(variant: :rad_primary, href: "/foo")) { "link" }
      expect(page).to have_css("a[href='/foo']")
    end

    it ":pill renders rounded-full" do
      render_inline(described_class.new(variant: :rad_primary, pill: true))
      expect(page).to have_css("button.rounded-full")
    end

    %i[sm md lg].each do |size|
      it "size #{size} renders the matching size class" do
        render_inline(described_class.new(variant: :rad_primary, size: size))
        case size
        when :sm then expect(page).to have_css("button.px-3.py-1\\.5.text-xs")
        when :md then expect(page).to have_css("button.px-4.py-2.text-sm")
        when :lg then expect(page).to have_css("button.px-6.py-3.text-base")
        end
      end
    end
  end

  describe "B1 token contract — no dead spec tokens leak in new semantic variants" do
    UNDEFINED_TOKENS = %w[
      accent-warning accent-success accent-danger
      surface-elevated surface-inverse on-inverse
      text-text-primary text-text-muted border-text-primary
    ].freeze

    %i[rad_primary secondary rad_ghost danger ink].each do |variant|
      it "variant :#{variant} does not reference undefined B1 tokens" do
        render_inline(described_class.new(variant: variant))
        html = page.native.to_html
        UNDEFINED_TOKENS.each do |bad|
          expect(html).not_to include(bad), "Button variant=#{variant} rendered undefined token '#{bad}'"
        end
      end
    end
  end
end
