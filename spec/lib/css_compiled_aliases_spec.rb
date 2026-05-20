require "rails_helper"

# T025 — FR-009 + US3 regression guard — verifies the 12 historical
# --color-rad-* aliases are still present in the compiled CSS after B1.
# These aliases must remain functional to keep existing views/components
# (PRs 054-057) rendering identically.
RSpec.describe "Compiled CSS — legacy --color-rad-* aliases" do
  include CssTokenReader

  let(:css) { read_compiled_css }

  %w[
    --color-rad-bg
    --color-rad-paper
    --color-rad-raise
    --color-rad-text
    --color-rad-muted
    --color-rad-rule
    --color-rad-red
    --color-rad-yellow
    --color-rad-teal
    --color-rad-green
    --color-rad-ink
    --color-rad-cream
    --color-rad-warm
  ].each do |alias_token|
    it "preserves alias #{alias_token}" do
      expect(css).to include(alias_token)
    end
  end
end
