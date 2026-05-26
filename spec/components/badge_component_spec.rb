require "rails_helper"

RSpec.describe BadgeComponent, type: :component do
  it "renders an indigo badge with light and dark variants" do
    render_inline(described_class.new(color: :indigo, label: "SIN"))

    expect(page).to have_text("SIN")
    # Light mode: dark text on light background for contrast
    expect(page).to have_css("span.text-indigo-700")
    # Dark mode: lighter text on tinted background
    expect(page).to have_css("span.dark\\:text-indigo-400")
  end

  it "renders an emerald badge with light and dark variants" do
    render_inline(described_class.new(color: :emerald, label: "2024"))

    expect(page).to have_text("2024")
    expect(page).to have_css("span.text-emerald-700")
    expect(page).to have_css("span.dark\\:text-emerald-400")
  end

  it "renders an amber badge" do
    render_inline(described_class.new(color: :amber, label: "Métropole"))

    expect(page).to have_text("Métropole")
  end

  it "renders a blue badge" do
    render_inline(described_class.new(color: :blue, label: "DT1"))

    expect(page).to have_text("DT1")
  end

  describe "new semantic variants" do
    {
      primary:   "accent-primary",
      secondary: "accent-secondary",
      warning:   "warning",
      success:   "success"
    }.each do |variant, token|
      it ":#{variant} renders bg-#{token}/10 + text-#{token} + border-#{token}/20" do
        render_inline(described_class.new(color: variant, label: "x"))
        html = page.native.to_html
        expect(html).to include("bg-#{token}/10")
        expect(html).to include("text-#{token}")
        expect(html).to include("border-#{token}/20")
      end
    end

    it ":neutral renders bg-rule/40 + text-on-surface-muted + border-rule" do
      render_inline(described_class.new(color: :neutral, label: "x"))
      html = page.native.to_html
      expect(html).to include("bg-rule/40")
      expect(html).to include("text-on-surface-muted")
      expect(html).to include("border-rule")
    end

    it ":specialty_sin renders accent-secondary tokens (teal, audience-swap aware)" do
      render_inline(described_class.new(color: :specialty_sin, label: "SIN"))
      html = page.native.to_html
      expect(html).to include("bg-accent-secondary/10")
      expect(html).to include("text-accent-secondary")
    end

    it ":specialty_itec renders warning tokens (amber)" do
      render_inline(described_class.new(color: :specialty_itec, label: "ITEC"))
      html = page.native.to_html
      expect(html).to include("bg-warning/10")
      expect(html).to include("text-warning")
    end

    it ":specialty_ec renders accent-primary tokens" do
      render_inline(described_class.new(color: :specialty_ec, label: "EC"))
      html = page.native.to_html
      expect(html).to include("bg-accent-primary/10")
      expect(html).to include("text-accent-primary")
    end
  end

  describe "deprecated legacy colors (pixel-perfect baseline)" do
    {
      indigo:     "bg-indigo-100",
      emerald:    "bg-emerald-100",
      amber:      "bg-amber-100",
      blue:       "bg-blue-100",
      slate:      "bg-slate-200",
      rose:       "bg-rose-100",
      rad_teal:   "bg-rad-teal/10",
      rad_red:    "bg-rad-red/10",
      rad_yellow: "bg-rad-yellow/15",
      rad_muted:  "bg-rad-rule/40"
    }.each do |color, expected_bg|
      it ":#{color} preserves the original bg class #{expected_bg}" do
        render_inline(described_class.new(color: color, label: "x"))
        expect(page.native.to_html).to include(expected_bg)
      end
    end
  end

  describe "B1 token contract — no dead spec tokens leak in" do
    # Guards against the spec drift from 2026-05-26 — these names exist in the
    # ORIGINAL spec but NOT in B1 application.css. Catching them prevents the
    # same class of bug that Card had pre-fix.
    UNDEFINED_TOKENS = %w[
      accent-warning accent-success accent-danger
      text-text-muted text-text-primary
    ].freeze

    %i[primary secondary warning success neutral specialty_sin specialty_itec specialty_ec].each do |color|
      it "color :#{color} does not reference undefined B1 tokens" do
        render_inline(described_class.new(color: color, label: "x"))
        html = page.native.to_html
        UNDEFINED_TOKENS.each do |bad|
          expect(html).not_to include(bad), "Badge color=#{color} rendered undefined token '#{bad}' — see B1 contract"
        end
      end
    end
  end
end
