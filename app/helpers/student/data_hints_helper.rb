module Student::DataHintsHelper
  SOURCE_LABELS = {
    "question_context" => "Contexte",
    "mise_en_situation" => "Présentation",
    "enonce" => "Énoncé",
    "tableau_sujet" => "Tableau du sujet"
  }.freeze

  def hint_source_label(source)
    SOURCE_LABELS[source] || source
  end

  def hint_badge_color(source)
    case source.to_s
    when /\ADT/i then :blue
    when /\ADR/i then :amber
    else :slate
    end
  end

  def primary_data_hint(question)
    return nil unless question&.answer

    hints = question.answer.data_hints
    return nil if hints.blank?

    hints.first
  end

  def data_hint_caption(hint)
    return nil unless hint.is_a?(Hash)

    source = hint["source"].presence
    location = hint["location"].presence
    return nil if source.blank? && location.blank?
    return location if source.blank?
    return source if location.blank?

    "#{source} · #{location}"
  end
end
