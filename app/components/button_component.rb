class ButtonComponent < ViewComponent::Base
  # New semantic variants (B5 migration targets) consume B1 design tokens.
  # Legacy aliases (:primary, :gradient, :success, :ghost) are kept pixel-perfect
  # to preserve the 36 existing call sites until B5 teacher reskin migrates them.
  # See issue #109.

  # DEPRECATED — see #109 — preserves the pre-B2a indigo gradient string for
  # 22+ teacher call sites passing variant: :primary (default) or :gradient.
  LEGACY_PRIMARY_CLASSES = "bg-gradient-to-br from-indigo-500 to-violet-500 text-white hover:from-indigo-600 hover:to-violet-600 focus-visible:ring-indigo-500 shadow-[0_0_16px_rgba(99,102,241,0.3)] disabled:opacity-60 disabled:saturate-50 disabled:shadow-none".freeze

  # DEPRECATED — see #109 — preserves the pre-B2a outline-slate for 13
  # call sites passing variant: :ghost.
  LEGACY_GHOST_CLASSES = "border border-slate-200 dark:border-slate-700 text-slate-700 dark:text-slate-300 hover:bg-slate-50 dark:hover:bg-slate-800 focus-visible:ring-slate-400 disabled:opacity-60".freeze

  private_constant :LEGACY_PRIMARY_CLASSES, :LEGACY_GHOST_CLASSES

  VARIANTS = {
    # Nouvelles variantes sémantiques (cibles B5) — tokens B1 réels.
    # Post-B5 cleanup (issue #109) will rename :rad_primary → :primary,
    # :rad_ghost → :ghost once the legacy aliases below are removed.
    rad_primary: "bg-accent-primary text-on-accent-primary hover:bg-accent-primary/90 focus-visible:ring-accent-secondary",
    secondary:   "bg-transparent border border-on-surface text-on-surface hover:bg-surface-raised focus-visible:ring-accent-secondary",
    rad_ghost:   "bg-transparent text-on-surface-muted hover:bg-surface-raised focus-visible:ring-accent-secondary",
    danger:      "bg-danger text-on-danger hover:bg-danger/90 focus-visible:ring-accent-secondary",
    # Forward-declared for B5 — not yet consumed in any view.
    # Pixel-validate before first use; semantic inversion = bg uses the text token, text uses the surface token.
    ink:         "bg-on-surface text-surface hover:bg-on-surface/90 focus-visible:ring-accent-secondary",

    # DEPRECATED — see #109 — preserved pixel-perfect for zero regression
    primary:  LEGACY_PRIMARY_CLASSES,
    gradient: LEGACY_PRIMARY_CLASSES,
    success:  "bg-emerald-500 text-white hover:bg-emerald-600 focus-visible:ring-emerald-500 disabled:opacity-60",
    ghost:    LEGACY_GHOST_CLASSES
  }.freeze

  SIZES = {
    sm: "px-3 py-1.5 text-xs",
    md: "px-4 py-2 text-sm",
    lg: "px-6 py-3 text-base"
  }.freeze

  def initialize(variant: :primary, size: :md, pill: false, href: nil,
                 disabled: false, loading: false, **html_options)
    @variant = variant.to_sym
    @size = size.to_sym
    @pill = pill
    @href = href
    @disabled = disabled
    @loading = loading
    @html_options = html_options
  end

  SEMANTIC_VARIANTS = %i[rad_primary secondary rad_ghost danger ink].freeze
  private_constant :SEMANTIC_VARIANTS

  def call
    semantic = SEMANTIC_VARIANTS.include?(@variant)

    css = class_names(
      "inline-flex items-center justify-center font-semibold transition-all",
      "focus-visible:outline-none focus-visible:ring-2",
      # focus-visible:ring-offset-2 is a new a11y addition; restrict to semantic
      # variants to preserve SC-2 pixel-perfect on the 36 legacy call sites.
      semantic ? "focus-visible:ring-offset-2" : nil,
      "cursor-pointer disabled:cursor-not-allowed",
      # gap-2 applies only when the spinner is rendered alongside content — keeps
      # legacy single-child buttons pixel-identical.
      @loading ? "gap-2" : nil,
      VARIANTS[@variant],
      SIZES[@size],
      @pill ? "rounded-full" : "rounded-lg",
      @disabled || @loading ? "opacity-60 cursor-not-allowed" : nil,
      # Caller-provided extra classes from html_options, if any.
      @html_options[:class]
    )

    extra_attrs = @html_options.except(:class).dup
    extra_attrs[:"aria-disabled"] = "true" if @disabled
    extra_attrs[:"aria-busy"]     = "true" if @loading
    # loading buttons are also disabled to prevent double-submit.
    extra_attrs[:disabled]        = true   if @disabled || @loading

    inner = if @loading
      spinner = content_tag(:span, "", class: "inline-block h-3 w-3 animate-spin rounded-full border-2 border-current border-r-transparent", "aria-hidden": "true")
      safe_join([ spinner, content ])
    else
      content
    end

    # An anchor with disabled: true is rendered without an href — strips both
    # the invalid HTML disabled attr AND the live href, so the link is truly
    # inert (clickable disabled <a> with href is a real UX/accessibility bug).
    if @href && !@disabled && !@loading
      extra_attrs.delete(:disabled)
      content_tag(:a, inner, href: @href, class: css, **extra_attrs)
    elsif @href
      extra_attrs.delete(:disabled)
      extra_attrs[:role] = "link"
      extra_attrs[:tabindex] = "-1"
      content_tag(:a, inner, class: css, **extra_attrs)
    else
      content_tag(:button, inner, class: css, **extra_attrs)
    end
  end
end
