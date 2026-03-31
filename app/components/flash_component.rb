class FlashComponent < ViewComponent::Base
  TYPES = {
    notice: "bg-emerald-50 dark:bg-emerald-500/10 text-emerald-700 dark:text-emerald-300 border-emerald-200 dark:border-emerald-500/20",
    alert:  "bg-rose-50 dark:bg-rose-500/10 text-rose-700 dark:text-rose-300 border-rose-200 dark:border-rose-500/20"
  }.freeze

  def initialize(type:, message:)
    @type = type.to_sym
    @message = message
  end

  def render?
    @message.present?
  end

  def call
    content_tag(:div, @message,
      class: "px-4 py-3 rounded-lg border text-sm #{TYPES[@type]}")
  end
end
