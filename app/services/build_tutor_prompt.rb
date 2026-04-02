# app/services/build_tutor_prompt.rb
class BuildTutorPrompt
  TASK_TYPE_LABELS = {
    "calculation"    => "Calculer une valeur",
    "text"           => "Rediger une reponse",
    "argumentation"  => "Justifier ou argumenter",
    "dr_reference"   => "Completer un document reponse",
    "completion"     => "Completer un schema ou tableau",
    "choice"         => "Choisir parmi des options"
  }.freeze

  DEFAULT_TEMPLATE = <<~PROMPT
    Tu es un tuteur bienveillant pour des eleves de Terminale preparant le BAC.
    Specialite : %{specialty}. Partie : %{part_title}. Objectif : %{objective_text}.
    Question : %{question_label}. Contexte local : %{context_text}.
    Correction officielle (confidentielle) : %{correction_text}.
    Regle absolue : ne donne JAMAIS la reponse directement.
    Guide l'eleve par etapes, valorise ses tentatives, pose des questions.
    Propose une fiche de revision si un concept cle est identifie.
    Reponds en francais, niveau lycee, de facon bienveillante.
  PROMPT

  def self.call(question:, student:)
    new(question: question, student: student).call
  end

  def initialize(question:, student:)
    @question = question
    @student  = student
  end

  def call
    prompt = interpolate_template
    prompt += insights_section if insights.any?
    prompt += spotting_context
    prompt
  end

  private

  def interpolate_template
    template % template_variables
  end

  def template
    subject.owner.tutor_prompt_template.presence || DEFAULT_TEMPLATE
  end

  def template_variables
    {
      specialty:       subject.specialty,
      part_title:      part.title,
      objective_text:  part.objective_text.to_s,
      question_label:  @question.label,
      context_text:    @question.context_text.to_s,
      correction_text: answer_correction_text
    }
  end

  def answer_correction_text
    @question.answer&.correction_text.to_s
  end

  def part
    @question.part
  end

  def subject
    part.subject
  end

  def insights
    @insights ||= StudentInsight.where(student: @student, subject: subject).order(:created_at)
  end

  def insights_section
    lines = [ "\n\n--- Historique de l'eleve ---" ]
    insights.each do |insight|
      lines << "- [#{insight.insight_type}] #{insight.concept}: #{insight.text}"
    end
    lines.join("\n")
  end

  def spotting_context
    session = StudentSession.find_by(student: @student, subject: subject)
    return "" unless session&.tutored?

    qstate = session.spotting_data(@question.id)
    return "" unless qstate

    lines = [ "\n\n--- Resultat du reperage de l'eleve ---" ]
    if qstate["task_type_correct"]
      lines << "- L'eleve a correctement identifie le type de tache (#{TASK_TYPE_LABELS[qstate['task_type_answer']] || qstate['task_type_answer']})"
    else
      lines << "- L'eleve pensait devoir '#{TASK_TYPE_LABELS[qstate['task_type_answer']]}' alors qu'il faut '#{TASK_TYPE_LABELS[@question.answer_type]}'. Guide-le sur ce point."
    end

    missed = qstate["sources_missed"] || []
    if missed.any?
      missed.each do |m|
        src = m.is_a?(Hash) ? m["source"] : m
        loc = m.is_a?(Hash) ? m["location"] : nil
        lines << "- Sources manquees : #{src}#{loc ? " (#{loc})" : ""}. Guide l'eleve vers cette source."
      end
    else
      lines << "- L'eleve a correctement identifie toutes les sources de donnees."
    end

    lines.join("\n")
  end
end
