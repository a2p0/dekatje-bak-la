class ButtonComponent < ViewComponent::Base
  VARIANTS = {
    primary: "bg-indigo-500 text-white hover:bg-indigo-600 focus-visible:ring-indigo-500 disabled:opacity-60",
    success: "bg-emerald-500 text-white hover:bg-emerald-600 focus-visible:ring-emerald-500 disabled:opacity-60",
    ghost: "border border-slate-200 dark:border-slate-700 text-slate-700 dark:text-slate-300 hover:bg-slate-50 dark:hover:bg-slate-800 focus-visible:ring-slate-400 disabled:opacity-60",
    gradient: "bg-gradient-to-br from-indigo-500 to-violet-500 text-white hover:from-indigo-600 hover:to-violet-600 focus-visible:ring-indigo-500 shadow-[0_0_16px_rgba(99,102,241,0.3)] disabled:opacity-60 disabled:saturate-50 disabled:shadow-none"
  }.freeze

  SIZES = {
    sm: "px-3 py-1.5 text-xs",
    md: "px-4 py-2 text-sm",
    lg: "px-6 py-3 text-base"
  }.freeze

  def initialize(variant: :primary, size: :md, pill: false, href: nil, **html_options)
    @variant = variant.to_sym
    @size = size.to_sym
    @pill = pill
    @href = href
    @html_options = html_options
  end

  def call
    css = class_names(
      "inline-flex items-center justify-center font-semibold transition-all focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-offset-2 cursor-pointer disabled:cursor-not-allowed",
      VARIANTS[@variant],
      SIZES[@size],
      @pill ? "rounded-full" : "rounded-lg"
    )

    if @href
      content_tag(:a, content, href: @href, class: css, **@html_options)
    else
      content_tag(:button, content, class: css, **@html_options)
    end
  end
end
