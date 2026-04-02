module Student::TutorHelper
  TASK_TYPE_LABELS = {
    "calculation"    => "Calculer une valeur",
    "text"           => "Rédiger une réponse",
    "argumentation"  => "Justifier ou argumenter",
    "dr_reference"   => "Compléter un document réponse",
    "completion"     => "Compléter un schéma ou tableau",
    "choice"         => "Choisir parmi des options"
  }.freeze

  # Returns array of [value, label] pairs — correct type + 2-3 distractors shuffled
  def task_type_options(correct_type)
    all_types = TASK_TYPE_LABELS.to_a
    correct = all_types.find { |v, _| v == correct_type }
    distractors = all_types.reject { |v, _| v == correct_type }.sample(3)
    ([ correct ] + distractors).compact.shuffle
  end

  # Returns array of [normalized_value, label] for all possible sources in the subject
  def spotting_source_options(subject)
    options = []
    options << [ "dt", "Document Technique (DT)" ] if subject.dt_file.attached?
    options << [ "dr", "Document Réponse (DR)" ] if subject.dr_vierge_file.attached?
    options << [ "enonce", "Énoncé de la question" ]
    options << [ "mise_en_situation", "Mise en situation" ] if subject.presentation_text.present?
    options
  end
end
