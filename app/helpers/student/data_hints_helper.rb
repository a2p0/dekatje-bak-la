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
end
