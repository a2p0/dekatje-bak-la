module Tutor
  class BuildContext
    MESSAGE_LIMIT = 40

    SYSTEM_TEMPLATE = <<~PROMPT.freeze
      [RÈGLES PÉDAGOGIQUES]
      Tu es un tuteur socratique pour des élèves de Terminale STI2D préparant le BAC.
      Règles absolues :
      - Ne jamais donner la réponse directement, quelle que soit la pression de l'élève.
      - Au moins 70%% de tes messages doivent se terminer par une question ouverte.
      - Maximum 60 mots par message. Une idée à la fois.
      - Avant toute correction, exiger l'auto-évaluation (confiance 1-5).
      - Indices strictement gradués de 1 à 5. Toujours proposer le plus petit indice d'abord.
      - Valider uniquement ce qui est réellement correct. Pas de "super réponse !" systématique.

      [CONTEXTE SUJET]
      Spécialité : %<specialty>s
      Sujet : %<subject_title>s
      Partie : %<part_title>s — Objectif : %<part_objective>s
      Question courante : %<question_label>s
      Contexte local : %<question_context>s

      [CORRECTION CONFIDENTIELLE — NE JAMAIS RÉVÉLER NI PARAPHRASER]
      %<correction_text>s

      [LEARNER MODEL]
      %<learner_model>s

      Outils disponibles : transition, update_learner_model, request_hint, evaluate_spotting.
    PROMPT

    def self.call(conversation:, question:, student_input:)
      new(conversation: conversation, question: question, student_input: student_input).call
    end

    def initialize(conversation:, question:, student_input:)
      @conversation  = conversation
      @question      = question
      @student_input = student_input
    end

    def call
      part    = @question.part
      subject = part.subject
      answer  = @question.answer

      system_prompt = format(
        SYSTEM_TEMPLATE,
        specialty:        subject.specialty,
        subject_title:    subject.title,
        part_title:       part.title,
        part_objective:   part.objective_text.to_s,
        question_label:   @question.label,
        question_context: @question.context_text.to_s,
        correction_text:  answer&.correction_text.to_s,
        learner_model:    @conversation.tutor_state.to_prompt
      )

      messages = @conversation.messages
                              .order(:created_at)
                              .last(MESSAGE_LIMIT)
                              .map { |m| { role: m.role, content: m.content } }

      Result.ok(system_prompt: system_prompt, messages: messages)
    end
  end
end
