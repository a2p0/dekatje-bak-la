class CardComponent < ViewComponent::Base
  renders_one :header
  renders_one :body
  renders_one :footer

  def initialize(variant: :default)
    @variant = variant.to_sym
  end

  def card_classes
    base = "bg-white rounded-xl overflow-hidden dark:bg-slate-800/80"

    case @variant
    when :glow
      "#{base} border border-slate-200 shadow-sm dark:border-indigo-500/15 dark:shadow-[0_0_15px_rgba(99,102,241,0.05)] transition-shadow hover:shadow-md dark:hover:shadow-[0_0_25px_rgba(99,102,241,0.15)]"
    else
      "#{base} border border-slate-200 shadow-sm dark:border-slate-700 dark:shadow-none"
    end
  end
end
