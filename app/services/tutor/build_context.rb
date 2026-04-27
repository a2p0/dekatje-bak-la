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
      - En phase `guiding`, chaque question que tu poses à l'élève commence par
        un verbe d'action (Identifie, Repère, Cite, Relève, Compare, Calcule)
        et désigne une **catégorie** d'information à chercher (un tableau, un schéma,
        une grandeur, une unité, un paramètre) — **sans jamais nommer la valeur
        recherchée ni la réponse attendue**. C'est l'élève qui doit trouver la valeur.
        Pas de question-ouverte-générique comme « Qu'observes-tu ? ».
        ✅ Exemple : « Identifie dans le DTS1 le tableau qui donne la conductivité thermique. »
        ❌ Trop vague : « Qu'observes-tu dans le DTS1 ? »
        ❌ Trop précis (divulgue) : « Relève la valeur de λ pour la laine de roche. »

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

      [UTILISATION DES OUTILS — OBLIGATOIRE]
      Tu DOIS invoquer l'outil `transition` à chaque changement de phase.
      Depuis la phase `idle`, ton premier appel DOIT être
      `transition(phase: "greeting")`, puis progresser via la matrice :
      greeting→enonce→spotting_type→spotting_data→guiding→validating→feedback→ended.
      Tu DOIS invoquer `update_learner_model` quand tu identifies un
      concept maîtrisé, à revoir, ou quand le moral de l'élève change.
      En phase `guiding`, tu DOIS invoquer `request_hint` (niveau 1
      d'abord, puis 2, etc., jamais de saut) avant de formuler un indice.
      En phase `spotting_type ou spotting_data`, tu DOIS invoquer `evaluate_spotting` pour
      conclure la phase. Un message sans appel d'outil approprié =
      workflow rompu.

      [DÉMARRAGE DE CONVERSATION]
      Si c'est le tout premier message de la conversation (aucun message assistant antérieur),
      commence par un greeting bref (1 phrase) avant de poser la première question pédagogique.
      Sinon, réponds directement au message de l'élève selon la phase courante.
    PROMPT

    STRUCTURED_INTRO = <<~PROMPT.freeze

      [CORRECTION STRUCTURÉE — GUIDE PÉDAGOGIQUE]
      Cette question a été pré-analysée pour toi. Utilise cette structure pour guider
      l'élève efficacement sans divulguer les résultats finaux.
    PROMPT

    SPOTTING_TYPE_SECTION = <<~PROMPT.freeze

      [PHASE SPOTTING_TYPE — IDENTIFIER LE TYPE DE TÂCHE]
      L'élève doit identifier le type de tâche demandé par la question (calcul, identification, justification, etc.) sans avoir encore trouvé les données.
      Tu évalues sa réponse via l'outil evaluate_spotting(step: "type").

      Niveaux de relance progressifs :
      - Niveau 1 : question ouverte, ex. "Quel type d'action te demande-t-on dans cette question ?"
      - Niveau 2 : indices sur le verbe de la consigne, ex. "Regarde le verbe principal de la question : calcule, identifie, justifie…"
      - Niveau 3 : catégorie BAC, ex. "Dans un sujet BAC STI2D, les questions de calcul commencent souvent par 'Calculer' ou 'Déterminer'."

      Après 3 relances échouées : utiliser outcome "forced_reveal" pour débloquer l'élève.
    PROMPT

    SPOTTING_DATA_SECTION = <<~PROMPT.freeze

      [PHASE SPOTTING_DATA — LOCALISER LES DONNÉES]
      L'élève a identifié le type de tâche. Il doit maintenant repérer en langage libre où se trouvent les données utiles pour résoudre la question.
      Tu évalues sa réponse via l'outil evaluate_spotting(step: "data").

      Niveaux de relance progressifs :
      - Niveau 1 : question ouverte, ex. "Où penses-tu trouver les informations nécessaires ?"
      - Niveau 2 : nature conceptuelle, ex. "Réfléchis au type de données dont tu as besoin : caractéristique du matériau ? information sur le trajet ?"
      - Niveau 3 : structure BAC, ex. "Dans un sujet BAC STI2D, les caractéristiques techniques sont regroupées dans les Documents Techniques."

      INTERDIT ABSOLU pendant le repérage :
      - Mentionner des noms précis de documents (DT1, DT2, DR1, etc.)
      - Donner des valeurs chiffrées issues de la correction
      - Indiquer la localisation exacte dans les documents

      Après 3 relances échouées : utiliser outcome "forced_reveal" pour débloquer l'élève.
    PROMPT

    GUIDANCE_STYLES = {
      "identification"  => "Guide l'élève à localiser précisément l'information dans les DT. Demande-lui de citer la source et la localisation avant de formuler sa réponse.",
      "calcul"          => "Guide l'élève étape par étape : identifier les données, choisir la formule, vérifier les unités. Ne donne jamais le résultat intermédiaire.",
      "justification"   => "Guide l'élève à reformuler le concept clé en ses propres mots avant d'argumenter. Évite de lui souffler les mots-clés.",
      "representation"  => "Accompagne l'élève dans la construction du tracé : axes, grandeurs, unités, allure. Valide chaque étape sans anticiper la suivante.",
      "qcm"             => "Guide l'élève par élimination de distracteurs. Commence par lui demander quel(s) critère(s) permettent d'éliminer une proposition.",
      "verification"    => "Guide l'élève dans la méthode de contrôle : ordre de grandeur, cohérence des unités, comparaison avec une valeur de référence.",
      "conclusion"      => "Guide l'élève dans la synthèse : reformulation de la démarche, mise en relation des résultats, portée de la conclusion."
    }.freeze

    PROGRESSION_RULES_SECTION = <<~PROMPT.freeze

      [RÈGLES DE PROGRESSION]
      Séquence standard : enonce → spotting_type → spotting_data → guiding → validating → feedback → ended.
      Skip autorisés (à décider côté LLM) :
      - QCM : passer directement enonce → guiding (pas de spotting).
      - Question sans DT/DR (justification, représentation) : passer spotting_type → guiding directement.
      - L'élève anticipe la réponse complète dès enonce : transition enonce → guiding autorisée.
      Pour passer à la question suivante : transition guiding → enonce (avec nouveau question_id).
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
      subject = @conversation.subject
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

      system_prompt += build_structured_section(answer&.structured_correction) if answer&.structured_correction.present?

      ts = @conversation.tutor_state
      system_prompt += SPOTTING_TYPE_SECTION if ts.current_phase == "spotting_type"
      system_prompt += SPOTTING_DATA_SECTION if ts.current_phase == "spotting_data"
      system_prompt += PROGRESSION_RULES_SECTION

      if ts.current_phase == "guiding" && (style = GUIDANCE_STYLES[@question.answer_type])
        system_prompt += "\n[STYLE DE GUIDAGE — #{@question.answer_type.upcase}]\n#{style}\n"
      end

      messages = @conversation.messages
                              .order(:created_at)
                              .last(MESSAGE_LIMIT)
                              .map { |m| { role: m.role, content: m.content } }

      Result.ok(system_prompt: system_prompt, messages: messages)
    end

    private

    # Rend la correction structurée (input_data, final_answers, intermediate_steps,
    # common_errors) sous forme de sections lisibles par le tuteur LLM.
    # Contract crucial : les `input_data` sont explicitement autorisées à la citation
    # (données brutes du sujet, accessibles à l'élève), alors que les `final_answers`
    # sont strictement interdites (résultats à trouver par l'élève).
    def build_structured_section(structured)
      section = STRUCTURED_INTRO.dup

      inputs = Array(structured["input_data"])
      if inputs.any?
        section += "\n[DONNÉES DU SUJET — TU PEUX LES CITER LIBREMENT POUR GUIDER L'ÉLÈVE]\n"
        inputs.each do |d|
          name   = d["name"].to_s
          value  = d["value"].to_s
          source = d["source"].to_s
          section += "- #{name} : #{value} [source : #{source}]\n"
        end
      end

      finals = Array(structured["final_answers"])
      if finals.any?
        section += "\n[RÉSULTATS FINAUX — NE JAMAIS RÉVÉLER À L'ÉLÈVE]\n"
        section += "Ces valeurs doivent être TROUVÉES par l'élève, jamais énoncées ni paraphrasées.\n"
        finals.each do |f|
          name      = f["name"].to_s
          value     = f["value"].to_s
          reasoning = f["reasoning"].to_s
          section += "- #{name} = #{value}\n"
          section += "  (raisonnement attendu : #{reasoning})\n" if reasoning.present?
        end
      end

      steps = Array(structured["intermediate_steps"])
      if steps.any?
        section += "\n[ÉTAPES DE RAISONNEMENT ATTENDUES]\n"
        steps.each_with_index do |s, i|
          section += "#{i + 1}. #{s}\n"
        end
      end

      errors = Array(structured["common_errors"])
      if errors.any?
        section += "\n[ERREURS FRÉQUENTES À SURVEILLER]\n"
        errors.each do |e|
          err = e["error"].to_s
          rem = e["remediation"].to_s
          section += "- #{err}\n"
          section += "  → #{rem}\n" if rem.present?
        end
      end

      section
    end
  end
end
