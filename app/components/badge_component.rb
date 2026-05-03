class BadgeComponent < ViewComponent::Base
  COLORS = {
    indigo:    "bg-indigo-100 text-indigo-700 dark:bg-indigo-500/15 dark:text-indigo-400",
    emerald:   "bg-emerald-100 text-emerald-700 dark:bg-emerald-500/15 dark:text-emerald-400",
    amber:     "bg-amber-100 text-amber-800 dark:bg-amber-500/15 dark:text-amber-400",
    blue:      "bg-blue-100 text-blue-700 dark:bg-blue-500/15 dark:text-blue-400",
    slate:     "bg-slate-200 text-slate-700 dark:bg-slate-500/15 dark:text-slate-400",
    rose:      "bg-rose-100 text-rose-700 dark:bg-rose-500/15 dark:text-rose-400",
    rad_teal:  "bg-rad-teal/10 text-rad-teal border border-rad-teal/20",
    rad_red:   "bg-rad-red/10 text-rad-red border border-rad-red/20",
    rad_yellow:"bg-rad-yellow/15 text-rad-ink border border-rad-yellow/30",
    rad_muted: "bg-rad-rule/40 text-rad-muted border border-rad-rule",
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
