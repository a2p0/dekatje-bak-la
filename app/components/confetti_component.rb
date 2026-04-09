class ConfettiComponent < ViewComponent::Base
  # Renders a trigger element that fires a canvas-confetti burst on mount.
  # Respects prefers-reduced-motion.
  def initialize
  end

  def call
    content_tag(:div, "", data: { controller: "confetti" }, class: "sr-only", aria: { hidden: true })
  end
end
