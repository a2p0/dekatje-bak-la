class CardComponent < ViewComponent::Base
  renders_one :header
  renders_one :body
  renders_one :footer

  # Maps accent key → real B1 semantic tokens.
  # B1 contract distinguishes "accent" (identity, audience-swapped) from
  # "state" (global success/warning/danger). Each entry pins the bg, the
  # on-color (text), and the border color used by :hero/:outlined variants.
  ACCENTS = {
    primary:   { bg: "accent-primary",   on: "on-accent-primary",   border: "accent-primary" },
    secondary: { bg: "accent-secondary", on: "on-accent-secondary", border: "accent-secondary" },
    warning:   { bg: "warning",          on: "on-warning",          border: "warning" },
    success:   { bg: "success",          on: "on-success",          border: "success" },
    danger:    { bg: "danger",           on: "on-danger",           border: "danger" }
  }.freeze

  def initialize(variant: :default, accent: nil)
    @variant = variant.to_sym
    @accent = accent&.to_sym
  end

  def card_classes
    base = "rounded-2xl overflow-hidden"

    case @variant
    when :default
      "#{base} bg-surface border border-rule"
    when :elevated
      "#{base} bg-surface-raised border border-rule shadow-sm"
    when :hero
      a = accent_tokens
      "#{base} bg-#{a[:bg]} text-#{a[:on]}"
    when :outlined
      a = accent_tokens
      "#{base} bg-transparent border-l-4 border-#{a[:border]}"
    # DEPRECATED — see #109
    when :rad
      "#{base} bg-rad-paper border border-rad-rule"
    # DEPRECATED — see #109
    when :glow
      "#{base} bg-white dark:bg-slate-800/80 border border-slate-200 shadow-sm dark:border-indigo-500/15 dark:shadow-[0_0_15px_rgba(99,102,241,0.05)] transition-shadow hover:shadow-md dark:hover:shadow-[0_0_25px_rgba(99,102,241,0.15)]"
    else
      # DEPRECATED legacy default — preserve pixel-perfect rendering — see #109
      "#{base} bg-white dark:bg-slate-800/80 border border-slate-200 shadow-sm dark:border-slate-700 dark:shadow-none"
    end
  end

  def footer_classes
    base = "px-5 py-4 border-t"

    case @variant
    when :hero
      a = accent_tokens
      # hero variant uses solid accent bg; footer border continues the accent color
      "#{base} border-#{a[:border]}"
    when :outlined
      a = accent_tokens
      "#{base} border-#{a[:border]}/30"
    when :default, :elevated
      "#{base} border-rule"
    # DEPRECATED legacy variants — preserve pre-B2a rendering — see #109
    else
      "#{base} border-rad-rule"
    end
  end

  private

  def accent_tokens
    ACCENTS.fetch(@accent || :primary)
  end
end
