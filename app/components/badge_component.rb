class BadgeComponent < ViewComponent::Base
  # Light mode: bg-{color}-100 text-{color}-700 (high contrast on white)
  # Dark mode:  bg-{color}-500/15 text-{color}-400 (vibrant on dark)
  COLORS = {
    indigo:  "bg-indigo-100 text-indigo-700 dark:bg-indigo-500/15 dark:text-indigo-400",
    emerald: "bg-emerald-100 text-emerald-700 dark:bg-emerald-500/15 dark:text-emerald-400",
    amber:   "bg-amber-100 text-amber-800 dark:bg-amber-500/15 dark:text-amber-400",
    blue:    "bg-blue-100 text-blue-700 dark:bg-blue-500/15 dark:text-blue-400",
    slate:   "bg-slate-200 text-slate-700 dark:bg-slate-500/15 dark:text-slate-400",
    rose:    "bg-rose-100 text-rose-700 dark:bg-rose-500/15 dark:text-rose-400"
  }.freeze

  def initialize(color:, label:)
    @color = color.to_sym
    @label = label
  end

  def call
    css = class_names(
      "inline-flex items-center px-2.5 py-1 rounded-full text-xs font-medium",
      COLORS[@color]
    )

    content_tag(:span, @label, class: css)
  end
end
