require "rails_helper"

# FR-014 + FR-003 — verifies the compiled Tailwind CSS contains the full
# token contract: 19 semantic tokens + 13 primitives + 6 audience×mode
# mapping blocks.
#
# This is a static artifact test (loads the compiled CSS file produced
# by `bin/rails tailwindcss:build`). No browser needed.
RSpec.describe "Compiled CSS — design tokens contract" do
  include CssTokenReader

  let(:css) { read_compiled_css }

  describe "19 semantic tokens (set minimum garanti, FR-003)" do
    %w[
      --color-surface
      --color-surface-raised
      --color-surface-sunken
      --color-on-surface
      --color-on-surface-muted
      --color-rule
      --color-rule-strong
      --color-accent-primary
      --color-on-accent-primary
      --color-accent-secondary
      --color-on-accent-secondary
      --color-success
      --color-on-success
      --color-warning
      --color-on-warning
      --color-danger
      --color-on-danger
      --color-info
      --color-on-info
    ].each do |token|
      it "declares #{token}" do
        expect(css).to include(token)
      end
    end
  end

  describe "13 primitives (couche source de vérité)" do
    %w[
      --rad-prim-cream
      --rad-prim-paper
      --rad-prim-raise
      --rad-prim-warm
      --rad-prim-ink
      --rad-prim-muted-light
      --rad-prim-muted-dark
      --rad-prim-rule-light
      --rad-prim-rule-dark
      --rad-prim-balisier-red
      --rad-prim-sun-yellow
      --rad-prim-sea-teal
      --rad-prim-grass-green
    ].each do |primitive|
      it "declares #{primitive}" do
        expect(css).to include(primitive)
      end
    end
  end

  describe "audience × mode mapping coverage" do
    # Tailwind v4 strips quotes: `[data-audience="x"]` → `[data-audience=x]`.
    # Selectors are NOT body-scoped so wrapper divs can demo multiple
    # audiences side-by-side (see CSS comment).
    #
    # Light overrides are per-audience (student/teacher/public must each
    # be addressable explicitly). Dark mode uses a generic selector
    # `html.dark [data-audience]` for the universal palette (the
    # teacher block then overrides accents). So we verify:
    #   - light: explicit per-audience selectors exist
    #   - dark : at minimum a generic [data-audience] block + the
    #            teacher-specific accent swap block.
    {
      "light/student" => /\[data-audience=student\]/,
      "light/teacher" => /\[data-audience=teacher\]/,
      "light/public"  => /\[data-audience=public\]/,
      "dark/universal"        => /html\.dark\s+\[data-audience\]/,
      "dark/teacher (swap)"   => /html\.dark\s+\[data-audience=teacher\]/
    }.each do |label, regex|
      it "contains mapping selector for #{label}" do
        expect(css).to match(regex)
      end
    end
  end
end
