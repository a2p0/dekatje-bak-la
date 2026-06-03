class NavBarComponent < ViewComponent::Base
  renders_one :brand
  renders_many :links, ->(href:, label:) {
    content_tag(:a, label, href: href,
      class: "text-sm text-on-surface-muted hover:text-on-surface transition-colors")
  }
  renders_one :actions
end
