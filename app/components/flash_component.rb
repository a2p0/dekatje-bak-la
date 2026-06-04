class FlashComponent < ViewComponent::Base
  TYPES = {
    notice: "bg-success/10 text-success border-success/20",
    alert:  "bg-danger/10 text-danger border-danger/20"
  }.freeze

  def initialize(type:, message:)
    @type = type.to_sym
    @message = message
  end

  def render?
    @message.present?
  end

  def call
    content_tag(:div, class: "flex items-center justify-between px-4 py-3 rounded-lg border text-sm #{TYPES.fetch(@type)}", data: { controller: "dismissable" }) do
      content_tag(:span, @message) +
      content_tag(:button, "×",
        class: "ml-3 text-current opacity-50 hover:opacity-100 cursor-pointer",
        data: { action: "click->dismissable#dismiss" },
        aria: { label: "Fermer" })
    end
  end
end
