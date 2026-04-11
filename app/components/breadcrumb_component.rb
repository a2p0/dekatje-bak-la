class BreadcrumbComponent < ViewComponent::Base
  # items: Array of hashes with :label (required) and :href (optional — nil for current/last item)
  # Example: [{label: "Mes sujets", href: "/sujets"}, {label: "BAC 2024", href: "/sujets/1"}, {label: "Q1.2"}]
  def initialize(items:)
    @items = items
  end

  def render?
    @items.any?
  end
end
