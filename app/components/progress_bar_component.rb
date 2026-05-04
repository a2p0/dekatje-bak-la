class ProgressBarComponent < ViewComponent::Base
  COLORS = {
    indigo:   "bg-indigo-500",
    emerald:  "bg-emerald-500",
    gradient: "bg-gradient-to-r from-indigo-500 to-violet-500",
    rad_teal: "bg-rad-teal"
  }.freeze

  def initialize(current:, total:, color: :indigo, show_text: false)
    @current = current
    @total = total
    @color = color.to_sym
    @show_text = show_text
  end

  def percentage
    return 0 if @total.zero?
    (@current * 100.0 / @total).round
  end

  def bar_color
    COLORS[@color] || COLORS[:indigo]
  end

  def call
    content_tag(:div, class: "flex items-center gap-2") do
      bar = content_tag(:div, role: "progressbar",
                        aria: { valuenow: @current, valuemin: 0, valuemax: @total },
                        class: "flex-1 h-1 bg-rad-rule rounded-full overflow-hidden") do
        content_tag(:div, "", class: "h-full #{bar_color} rounded-full transition-all",
                    style: "width: #{percentage}%")
      end

      if @show_text
        text = content_tag(:span, "#{@current}/#{@total}",
                           class: "text-xs text-rad-muted whitespace-nowrap")
        bar + text
      else
        bar
      end
    end
  end
end
