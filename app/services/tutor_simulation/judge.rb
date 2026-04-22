module TutorSimulation
  class Judge
    CRITERIA = [
      { key: :non_divulgation,    label: "Non-divulgation",
        description: "Le tuteur n'a-t-il JAMAIS donné la réponse directement ?" },
      { key: :guidage_progressif, label: "Guidage progressif",
        description: "Guide-t-il par étapes plutôt que tout d'un coup ?" },
      { key: :bienveillance,      label: "Bienveillance",
        description: "Ton encourageant, valorise les tentatives ?" },
      { key: :focalisation,       label: "Focalisation",
        description: "Reste-t-il ancré sur la question, recadre-t-il les dérives élève ?" },
      { key: :respect_process,    label: "Respect du process",
        description: "Suit-il une logique de phases (lecture → repérage → guidage → validation) ?" }
    ].freeze

    SYSTEM_PROMPT = <<~PROMPT
      Tu es un évaluateur expert en pédagogie. Tu analyses des transcripts de conversation
      entre un tuteur IA et un élève de Terminale STI2D préparant le BAC.

      Le tuteur est censé suivre un process en plusieurs phases :
        greeting → reading → spotting (où trouver les données ?) → guiding (résolution
        guidée) → validating (auto-évaluation de l'élève) → feedback (correction).
      Il dispose d'outils internes : transition (changer de phase), update_learner_model,
      request_hint (indices gradués 1 à 5), evaluate_spotting (juger le repérage).

      Tu dois évaluer le tuteur sur 5 critères orthogonaux, chacun noté de 1 à 5 :

      1. **Non-divulgation** (1-5) : Le tuteur n'a-t-il JAMAIS révélé à l'élève les
         **résultats finaux** (final_answers) qu'il devait trouver lui-même ?

         IMPORTANT — distinction critique :
         - Les **données d'entrée** (input_data) sont les valeurs lisibles par
           l'élève dans les documents du sujet (DT/DTS/DR/DRS/contexte/énoncé).
           Le tuteur PEUT les citer librement pour guider : ce n'est PAS une
           divulgation. Exemple : « L'épaisseur de la laine de roche est de
           0,08 m dans le DTS1 » est légitime si 0,08 m provient du DTS1.
         - Les **résultats finaux** (final_answers) sont les valeurs ou
           conclusions que l'élève doit trouver par raisonnement / calcul /
           analyse. Les révéler est une divulgation.
         - En cas de chaînage entre questions (une réponse de Q1 devient donnée
           d'entrée de Q2), les valeurs d'entrée de Q2 incluent légitimement
           les résultats de Q1 : citer R(laine de roche) = 5,29 en Q2 n'est
           pas une divulgation si Q1 demandait ce calcul.

         Le contexte fourni plus bas indique explicitement input_data vs
         final_answers quand disponible. Si absent, utiliser le jugement
         pédagogique : ce que l'élève doit chercher/calculer/conclure est
         à protéger, ce qui est lisible directement dans le sujet est OK.

         5 = jamais révélé aucun résultat final ; 1 = a révélé la totalité
         de la réponse attendue.

      2. **Guidage progressif** (1-5) : Guide-t-il par étapes plutôt que tout d'un coup ?
         5 = progression parfaite étape par étape, 1 = tout donné d'un bloc.

      3. **Bienveillance** (1-5) : Ton encourageant, valorise les tentatives ?
         5 = très bienveillant, 1 = froid ou décourageant.

      4. **Focalisation** (1-5) : Reste-t-il ancré sur la question ET recadre-t-il l'élève
         qui dérive ?
         5 = toujours pertinent, recadre fermement les digressions ; 1 = se laisse
         entraîner hors sujet ou ignore l'objectif pédagogique.

      5. **Respect du process** (1-5) : Suit-il la logique pédagogique attendue (greeting,
         lecture, repérage, guidage, validation, feedback) plutôt que de répondre à tout
         d'un coup ?
         5 = progression de phase visible et adaptée ; 1 = répond directement, ignore le
         process, saute des étapes essentielles.

      Réponds UNIQUEMENT en JSON valide, sans markdown, sans commentaire :
      {
        "non_divulgation":    {"score": N, "justification": "..."},
        "guidage_progressif": {"score": N, "justification": "..."},
        "bienveillance":      {"score": N, "justification": "..."},
        "focalisation":       {"score": N, "justification": "..."},
        "respect_process":    {"score": N, "justification": "..."},
        "synthese": "Résumé global en 2-3 phrases"
      }
    PROMPT

    def initialize(client:)
      @client = client
    end

    def evaluate(question_label:, student_profile:, correction_text:, transcript:, structured_correction: nil)
      formatted = format_transcript(transcript)
      structured_section = format_structured_correction(structured_correction)

      user_message = <<~MSG
        ## Contexte
        Question : #{question_label}
        Profil de l'élève simulé : #{student_profile}
        Réponse officielle (confidentielle, le tuteur la connaît) : #{correction_text}
        #{structured_section}
        ## Transcript
        #{formatted}

        Évalue ce transcript selon les 5 critères. Réponds en JSON.
      MSG

      response = @client.call(
        messages:    [ { role: "user", content: user_message } ],
        system:      SYSTEM_PROMPT,
        max_tokens:  1024,
        temperature: 0.1
      )

      parse_evaluation(response)
    end

    private

    # Renders the structured_correction (input_data / final_answers / ...) as
    # extra context for the judge. Returns "" when not provided, so the
    # user_message stays clean for legacy Answers without enrichment.
    def format_structured_correction(structured)
      return "" if structured.blank?

      lines = [ "", "## Décomposition structurée de la correction" ]

      inputs = Array(structured["input_data"])
      if inputs.any?
        lines << ""
        lines << "DONNÉES D'ENTRÉE (lisibles par l'élève — citer ces valeurs n'est PAS une divulgation) :"
        inputs.each do |d|
          lines << "- #{d['name']} = #{d['value']} [source : #{d['source']}]"
        end
      end

      finals = Array(structured["final_answers"])
      if finals.any?
        lines << ""
        lines << "RÉSULTATS FINAUX (à trouver par l'élève — révéler ces valeurs EST une divulgation) :"
        finals.each do |f|
          lines << "- #{f['name']} = #{f['value']}"
        end
      end

      lines << ""
      lines.join("\n")
    end

    def format_transcript(transcript)
      transcript.map do |msg|
        role_label = msg["role"] == "user" ? "ÉLÈVE" : "TUTEUR"
        "> **#{role_label}** : #{msg['content']}"
      end.join("\n\n")
    end

    def parse_evaluation(response)
      cleaned = response.gsub(/\A```json\s*/, "").gsub(/\s*```\z/, "").strip
      JSON.parse(cleaned)
    rescue JSON::ParserError
      { "error" => "Failed to parse judge response", "raw" => response }
    end
  end
end
