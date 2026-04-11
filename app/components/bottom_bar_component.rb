class BottomBarComponent < ViewComponent::Base
  # Mobile-only fixed bottom bar with prev/next navigation and an optional center action.
  #
  # Usage:
  #   render(BottomBarComponent.new(prev_href: ..., prev_label: "Q1.1", next_href: ..., next_label: "Q1.3")) do |bar|
  #     bar.with_center { render(ButtonComponent.new(variant: :gradient) { "Tutorat" }) }
  #   end
  renders_one :center

  def initialize(prev_href: nil, prev_label: nil, next_href: nil, next_label: nil, next_variant: :gradient)
    @prev_href = prev_href
    @prev_label = prev_label
    @next_href = next_href
    @next_label = next_label
    @next_variant = next_variant.to_sym
  end
end
