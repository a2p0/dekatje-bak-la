# app/services/build_tutor_prompt.rb
class BuildTutorPrompt
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
end
