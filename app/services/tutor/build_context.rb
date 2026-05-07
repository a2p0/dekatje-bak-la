module Tutor
  # 062: assembles the system prompt in 6 blocks.
  # Posture / Contexte question / Correction structurée / État d'aide /
  # Cap résultat final / Action attendue (with behavior_hint).
  class BuildContext
    MESSAGE_LIMIT = 40

    POSTURE = <<~POSTURE.freeze
      [POSTURE]
      Tu es un prof de STI2D qui aide un élève à réussir un sujet de BAC.
      Tu tutoies, tu es bienveillant, sympa, direct, sans détour.
      Pas familier-camarade, pas formel-distant. Tu parles court : 1-3 phrases par message.

      Tu peux donner les concepts, formules, méthodes, valeurs et calculs. Ton objectif est
      que l'élève réussisse cette question, pas qu'il devine seul. Mais à chaque palier,
      propose-lui d'essayer avant de donner. Quand l'élève bloque, demande où exactement,
      et donne juste ce qu'il faut pour qu'il puisse continuer.
    POSTURE

    def self.call(conversation:, question:, student_input:, last_signal:)
      new(conversation: conversation, question: question,
          student_input: student_input, last_signal: last_signal).call
    end

    def initialize(conversation:, question:, student_input:, last_signal:)
      @conversation  = conversation
      @question      = question
      @student_input = student_input
      @last_signal   = last_signal
    end

    def call
      prompt = +""
      prompt << POSTURE
      prompt << build_context_block
      prompt << build_correction_block
      prompt << build_budget_block
      prompt << build_cap_block
      prompt << build_action_block

      messages = @conversation.messages
                              .where(question_id: @question.id)
                              .order(:created_at)
                              .last(MESSAGE_LIMIT)
                              .map { |m| { role: m.role, content: m.content } }

      Result.ok(system_prompt: prompt, messages: messages)
    end

    private

    def trace
      @trace ||= @conversation.tutor_state.trace_for(@question.id)
    end

    def budget
      @budget ||= trace.budget
    end

    def build_context_block
      part = @question.part
      subject = @conversation.subject

      <<~CTX

        [CONTEXTE QUESTION]
        Spécialité : #{subject.specialty}
        Sujet : #{subject.title}
        Partie #{part.number} — #{part.title}
        Objectif de la partie : #{part.objective_text}

        Question #{@question.number} (#{@question.answer_type}) : #{@question.label}
        Contexte local : #{@question.context_text}
      CTX
    end

    def build_correction_block
      sc = @question.answer&.structured_correction
      return "" if sc.blank?

      block = +"\n[CORRECTION STRUCTURÉE]\n"

      inputs = Array(sc["input_data"])
      if inputs.any?
        block << "\n[DONNÉES DU SUJET — TU PEUX LES CITER LIBREMENT]\n"
        inputs.each do |d|
          block << "- #{d['name']} : #{d['value']} [#{d['source']}]\n"
        end
      end

      steps = Array(sc["intermediate_steps"])
      if steps.any?
        block << "\n[ÉTAPES DE RAISONNEMENT ATTENDUES]\n"
        steps.each_with_index { |s, i| block << "#{i + 1}. #{s}\n" }
      end

      finals = Array(sc["final_answers"])
      if finals.any?
        block << "\n[RÉSULTAT FINAL — VOIR CAP CI-DESSOUS]\n"
        finals.each do |f|
          block << "- #{f['name']} = #{f['value']}\n"
          block << "  (raisonnement attendu : #{f['reasoning']})\n" if f["reasoning"].present?
        end
      end

      errors = Array(sc["common_errors"])
      if errors.any?
        block << "\n[ERREURS FRÉQUENTES À SURVEILLER]\n"
        errors.each do |e|
          block << "- #{e['error']}\n"
          block << "  → #{e['remediation']}\n" if e["remediation"].present?
        end
      end

      block
    end

    def build_budget_block
      <<~BUDGET

        [ÉTAT D'AIDE]
        - Formule/méthode donnée   : #{yes_no(budget[:formule_given])}
        - Valeurs identifiées      : #{yes_no(budget[:value_given])}
        - Calcul détaillé donné    : #{yes_no(budget[:calc_given])}
        - Résultat final révélé    : #{yes_no(budget[:result_given])}
        - Tentatives de l'élève    : #{budget[:attempts_count]}
        - Correction vue par l'élève : #{yes_no(budget[:viewed_correction])}

        Adapte ta réponse en fonction. Ne re-donne pas ce qui est déjà donné. Pousse l'élève
        sur le palier suivant.
      BUDGET
    end

    def build_cap_block
      <<~CAP

        [CAP RÉSULTAT FINAL]
        Résumé : le cap se lève si tentatives ≥ 2 OU correction vue.

        Tu peux donner le résultat final si :
        - l'élève a déjà fait ≥ 2 tentatives, OU
        - l'élève a déjà vu la correction.

        Sinon, refuse de le donner. Si l'élève le demande quand même :
        propose-lui une dernière tentative avec un dernier indice,
        ou de cliquer "afficher la correction" sur la page.
      CAP
    end

    def build_action_block
      hint = BehaviorHints.for(
        signal:      @last_signal || :default,
        answer_type: @question.answer_type.to_s,
        budget:      budget
      )

      summary = build_signal_summary

      <<~ACT

        [ACTION ATTENDUE]
        #{summary}

        Comportement attendu :
        #{hint}
      ACT
    end

    def build_signal_summary
      case @last_signal
      when :fresh_open
        "L'élève vient d'ouvrir le drawer pour la première fois sur ce sujet."
      when :opened_after_data_hints
        "L'élève vient de cliquer 'afficher data_hints' sur la page question."
      when :opened_after_correction
        "L'élève vient de cliquer 'afficher la correction' sur la page question."
      when :navigation_arrival
        if budget[:attempts_count].positive?
          "L'élève revient sur cette question (déjà entamée — #{budget[:attempts_count]} tentative(s))."
        else
          "L'élève arrive sur cette question pour la première fois."
        end
      when :wrong_attempt
        "L'élève vient de faire une tentative incorrecte. Contenu : #{@student_input.to_s.strip}."
      when :correct_attempt
        "L'élève vient de faire une tentative correcte."
      when :dont_understand
        "L'élève vient d'écrire qu'il ne comprend pas / bloque (\"#{@student_input.to_s.strip}\")."
      when :chip_formule, :chip_valeur, :chip_calcul, :chip_resultat
        "L'élève vient de cliquer le chip #{@last_signal.to_s.sub(/^chip_/, '').upcase} dans le drawer."
      else
        "Message élève : \"#{@student_input.to_s.strip}\"."
      end
    end

    def yes_no(value)
      value ? "OUI" : "NON"
    end
  end
end
