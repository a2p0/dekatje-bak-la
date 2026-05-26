class BadgeComponent < ViewComponent::Base
  # Pattern sémantique B2a : bg-{token}/10 + text-{token} + border + border-{token}/20
  # Pattern neutral       : bg-rule/40 + text-on-surface-muted + border + border-rule
  # Legacy (DEPRECATED #109) : strings figées pixel-perfect.

  COLORS = {
    # Nouvelles variantes sémantiques — consomment les tokens B1 (cf. spec §5.3)
    primary:        "bg-accent-primary/10 text-accent-primary border border-accent-primary/20",
    secondary:      "bg-accent-secondary/10 text-accent-secondary border border-accent-secondary/20",
    warning:        "bg-warning/10 text-warning border border-warning/20",
    success:        "bg-success/10 text-success border border-success/20",
    neutral:        "bg-rule/40 text-on-surface-muted border border-rule",
    # Specialty variants map to the model enum keys (Subject/Part/Student#specialty: SIN, ITEC, EE, AC).
    # Pattern-driven dispatch from views: `BadgeComponent.new(color: :"specialty_#{subject.specialty.downcase}", …)`.
    specialty_sin:  "bg-accent-secondary/10 text-accent-secondary border border-accent-secondary/20",
    specialty_itec: "bg-warning/10 text-warning border border-warning/20",
    specialty_ee:   "bg-accent-primary/10 text-accent-primary border border-accent-primary/20",
    specialty_ac:   "bg-rule/40 text-on-surface-muted border border-rule",

    # DEPRECATED — see #109 — preserved pixel-perfect for zero visual regression on existing 10 call sites
    indigo:     "bg-indigo-100 text-indigo-700 dark:bg-indigo-500/15 dark:text-indigo-400",
    emerald:    "bg-emerald-100 text-emerald-700 dark:bg-emerald-500/15 dark:text-emerald-400",
    amber:      "bg-amber-100 text-amber-800 dark:bg-amber-500/15 dark:text-amber-400",
    blue:       "bg-blue-100 text-blue-700 dark:bg-blue-500/15 dark:text-blue-400",
    slate:      "bg-slate-200 text-slate-700 dark:bg-slate-500/15 dark:text-slate-400",
    rose:       "bg-rose-100 text-rose-700 dark:bg-rose-500/15 dark:text-rose-400",
    rad_teal:   "bg-rad-teal/10 text-rad-teal border border-rad-teal/20",
    rad_red:    "bg-rad-red/10 text-rad-red border border-rad-red/20",
    rad_yellow: "bg-rad-yellow/15 text-rad-ink border border-rad-yellow/30",
    rad_muted:  "bg-rad-rule/40 text-rad-muted border border-rad-rule"
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
