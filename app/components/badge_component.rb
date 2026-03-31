class BadgeComponent < ViewComponent::Base
  COLORS = {
    indigo:  "bg-indigo-500/10 text-indigo-300 dark:bg-indigo-500/10 dark:text-indigo-300",
    emerald: "bg-emerald-500/10 text-emerald-300 dark:bg-emerald-500/10 dark:text-emerald-300",
    amber:   "bg-amber-500/10 text-amber-300 dark:bg-amber-500/10 dark:text-amber-300",
    blue:    "bg-blue-500/10 text-blue-300 dark:bg-blue-500/10 dark:text-blue-300",
    slate:   "bg-slate-500/10 text-slate-400 dark:bg-slate-500/10 dark:text-slate-400",
    rose:    "bg-rose-500/10 text-rose-300 dark:bg-rose-500/10 dark:text-rose-300"
  }.freeze

  def initialize(color:, label:)
    @color = color.to_sym
    @label = label
  end

  def call
    css = class_names(
      "inline-flex items-center px-2 py-0.5 rounded text-xs font-medium",
      COLORS[@color]
    )

    content_tag(:span, @label, class: css)
  end
end
