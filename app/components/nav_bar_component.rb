class NavBarComponent < ViewComponent::Base
  renders_one :brand
  renders_many :links, ->(href:, label:) {
    content_tag(:a, label, href: href,
      class: "text-sm text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-slate-200 transition-colors")
  }
  renders_one :breadcrumb
  renders_one :actions
end
