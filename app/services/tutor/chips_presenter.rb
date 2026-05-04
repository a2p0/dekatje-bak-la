module Tutor
  class ChipsPresenter
    CONFIDENCE_LABELS = {
      1 => "😰 Pas du tout sûr",
      2 => "😅 Peu sûr",
      3 => "🙂 Moyennement sûr",
      4 => "😊 Assez sûr",
      5 => "💪 Très sûr"
    }.freeze

    CONFIDENCE_COLORS = { 1 => :red, 2 => :yellow, 3 => :teal, 4 => :teal, 5 => :teal }.freeze

    def self.call(phase:, hints_used: 0)
      new(phase: phase, hints_used: hints_used).call
    end

    def initialize(phase:, hints_used: 0)
      @phase      = phase.to_s
      @hints_used = hints_used.to_i
    end

    def call
      case @phase
      when "greeting", "enonce"             then greeting_chips
      when "spotting_type", "spotting_data" then spotting_chips
      when "guiding"                        then guiding_chips
      when "validating"                     then validating_chips
      when "feedback", "ended"              then feedback_chips
      else []
      end
    end

    private

    def greeting_chips
      [
        send_chip("Reformule la question", "Peux-tu reformuler la question ?", :teal),
        send_chip("Définis un terme",      "Peux-tu définir un terme clé ?",    :red)
      ]
    end

    def spotting_chips
      [
        send_chip("Donne un exemple",      "Donne-moi un exemple.",              :yellow),
        send_chip("Reformule la question", "Peux-tu reformuler la question ?",   :teal)
      ]
    end

    def guiding_chips
      hint_disabled = @hints_used >= Tutor::ApplyToolCalls::MAX_HINTS
      hint      = send_chip("Un indice", "Donne-moi un indice.", :yellow, disabled: hint_disabled)
      reformule = send_chip("Reformule", "Peux-tu reformuler la question ?", :teal)
      definis   = send_chip("Définis",   "Peux-tu définir un terme clé ?",   :red)

      hint_disabled ? [reformule, definis, hint] : [hint, reformule, definis]
    end

    def validating_chips
      (1..5).map do |level|
        {
          label:   CONFIDENCE_LABELS[level],
          action:  :confidence,
          level:   level,
          color:   CONFIDENCE_COLORS[level],
          stacked: true
        }
      end
    end

    def feedback_chips
      [
        send_chip("Explique la correction", "Explique-moi la correction.", :teal),
        { label: "Question suivante →", action: :navigate, color: :red }
      ]
    end

    def send_chip(label, text, color, disabled: false)
      { label: label, action: :send, text: text, color: color, disabled: disabled }
    end
  end
end
