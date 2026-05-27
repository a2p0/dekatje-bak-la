class StripesComponent < ViewComponent::Base
  # Radical signature: 4 horizontal stripes, 5px tall, audience-aware via accent tokens.
  # Decorative only — aria-hidden="true". Zero params (signature is fixed).
  #
  # Color mapping (B1 semantic tokens):
  #   stripe 1 → accent-primary   (red on student, teal on teacher after audience swap)
  #   stripe 2 → warning          (yellow, global state token — identical across audiences)
  #   stripe 3 → accent-secondary (teal on student, red on teacher)
  #   stripe 4 → on-surface       (ink in light, cream in dark)
  def call
    content_tag(:div, class: "flex h-[5px] flex-shrink-0", "aria-hidden": "true") do
      safe_join([
        content_tag(:div, "", class: "flex-1 bg-accent-primary"),
        content_tag(:div, "", class: "flex-1 bg-warning"),
        content_tag(:div, "", class: "flex-1 bg-accent-secondary"),
        content_tag(:div, "", class: "flex-1 bg-on-surface")
      ])
    end
  end
end
