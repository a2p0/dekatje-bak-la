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

  describe "6 audience × mode mapping blocks" do
    # Note: Tailwind v4 compiles `[data-audience="x"]` to `[data-audience=x]`
    # (strips quotes). Selector is NOT body-scoped so wrapper divs can
    # demo multiple audiences side-by-side (see CSS comment).
    {
      "student (light)" => /\[data-audience=student\]/,
      "teacher (light)" => /\[data-audience=teacher\]/,
      "public (light)"  => /\[data-audience=public\]/,
      "student (dark)"  => /html\.dark\s+\[data-audience=student\]/,
      "teacher (dark)"  => /html\.dark\s+\[data-audience=teacher\]/,
      "public (dark)"   => /html\.dark\s+\[data-audience=public\]/
    }.each do |label, regex|
      it "contains mapping selector for #{label}" do
        expect(css).to match(regex)
      end
    end
  end
end
