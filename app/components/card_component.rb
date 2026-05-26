class CardComponent < ViewComponent::Base
  renders_one :header
  renders_one :body
  renders_one :footer

  ACCENT_TOKENS = {
    primary:   "accent-primary",
    secondary: "accent-secondary",
    warning:   "accent-warning",
    success:   "accent-success"
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
      "#{base} bg-surface-elevated border border-rule shadow-sm"
    when :hero
      accent_token = ACCENT_TOKENS.fetch(@accent || :primary)
      "#{base} bg-#{accent_token} text-on-accent"
    when :outlined
      accent_token = ACCENT_TOKENS.fetch(@accent || :primary)
      "#{base} bg-transparent border-l-4 border-#{accent_token}"
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
      accent_token = ACCENT_TOKENS.fetch(@accent || :primary)
      # hero variant on dark accent bg: border continues the accent color
      "#{base} border-#{accent_token}"
    when :outlined
      accent_token = ACCENT_TOKENS.fetch(@accent || :primary)
      "#{base} border-#{accent_token}/30"
    when :default, :elevated
      "#{base} border-rule"
    # DEPRECATED legacy variants — preserve pre-B2a rendering — see #109
    else
      "#{base} border-rad-rule"
    end
  end
end
