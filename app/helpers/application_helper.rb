module ApplicationHelper
  def scope_label(session_record, subject)
    case session_record.part_filter
    when "common_only"
      "Partie commune (12 pts, 2h30)"
    when "specific_only"
      "Partie specifique #{subject.specialty&.upcase} (8 pts, 1h30)"
    else
      "Sujet complet (20 pts, 4h)"
    end
  end
end
