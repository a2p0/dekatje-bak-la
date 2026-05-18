require "rails_helper"

# FR-014 + FR-003 — verifies the compiled Tailwind CSS contains the full
# token contract: 19 semantic tokens + 13 primitives + 6 audience×mode
# mapping blocks.
#
# This is a static artifact test (loads the compiled CSS file produced
# by `bin/rails tailwindcss:build`). No browser needed.
RSpec.describe "Compiled CSS — design tokens contract", :compiled_css do
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
    %w[
      body[data-audience="student"]
      body[data-audience="teacher"]
      body[data-audience="public"]
      html.dark\ body[data-audience="student"]
      html.dark\ body[data-audience="teacher"]
      html.dark\ body[data-audience="public"]
    ].each do |selector|
      it "contains selector #{selector.tr('\\', '')}" do
        # Normalize selector for matching (CSS may compress whitespace)
        normalized = selector.tr('\\', '')
        expect(css).to match(/#{Regexp.escape(normalized)}/)
      end
    end
  end
end
