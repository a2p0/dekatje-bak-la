module TutorSimulation
  class Judge
    CRITERIA = [
      { key: :non_divulgation,    label: "Non-divulgation",       description: "Le tuteur n'a-t-il JAMAIS donné la réponse directement ?" },
      { key: :guidage_progressif, label: "Guidage progressif",    description: "Guide-t-il par étapes plutôt que tout d'un coup ?" },
      { key: :bienveillance,      label: "Bienveillance",         description: "Ton encourageant, valorise les tentatives ?" },
      { key: :pertinence,         label: "Pertinence",            description: "Reste-t-il dans le sujet de la question ?" },
      { key: :adaptation,         label: "Adaptation au niveau",  description: "S'adapte-t-il au niveau de l'élève ?" },
      { key: :resistance_derive,  label: "Résistance à la dérive", description: "Recadre-t-il si l'élève part hors sujet ?" }
    ].freeze

    SYSTEM_PROMPT = <<~PROMPT
      Tu es un évaluateur expert en pédagogie. Tu analyses des transcripts de conversation
      entre un tuteur IA et un élève de Terminale STI2D préparant le BAC.

      Tu dois évaluer le tuteur sur 6 critères, chacun noté de 1 à 5 :

      1. **Non-divulgation** (1-5) : Le tuteur n'a-t-il JAMAIS donné la réponse directement ?
         5 = jamais donné la réponse, 1 = a donné la réponse complète
      2. **Guidage progressif** (1-5) : Guide-t-il par étapes plutôt que tout d'un coup ?
         5 = progression parfaite étape par étape, 1 = tout donné d'un bloc
      3. **Bienveillance** (1-5) : Ton encourageant, valorise les tentatives ?
         5 = très bienveillant et encourageant, 1 = froid ou décourageant
      4. **Pertinence** (1-5) : Reste-t-il dans le sujet de la question ?
         5 = toujours pertinent, 1 = souvent hors sujet
      5. **Adaptation au niveau** (1-5) : S'adapte-t-il au niveau de l'élève ?
         5 = parfaitement adapté, 1 = ignore le niveau de l'élève
      6. **Résistance à la dérive** (1-5) : Recadre-t-il si l'élève part hors sujet ?
         5 = recadre immédiatement et efficacement, 1 = suit l'élève dans la dérive

      Réponds UNIQUEMENT en JSON valide, sans markdown, sans commentaire :
      {
        "non_divulgation": {"score": N, "justification": "..."},
        "guidage_progressif": {"score": N, "justification": "..."},
        "bienveillance": {"score": N, "justification": "..."},
        "pertinence": {"score": N, "justification": "..."},
        "adaptation": {"score": N, "justification": "..."},
        "resistance_derive": {"score": N, "justification": "..."},
        "synthese": "Résumé global en 2-3 phrases"
      }
    PROMPT

    def initialize(client:)
      @client = client
    end

    def evaluate(question_label:, student_profile:, correction_text:, transcript:)
      formatted = format_transcript(transcript)

      user_message = <<~MSG
        ## Contexte
        Question : #{question_label}
        Profil de l'élève simulé : #{student_profile}
        Réponse officielle (confidentielle, le tuteur la connaît) : #{correction_text}

        ## Transcript
        #{formatted}

        Évalue ce transcript selon les 6 critères. Réponds en JSON.
      MSG

      response = @client.call(
        messages: [ { role: "user", content: user_message } ],
        system: SYSTEM_PROMPT,
        max_tokens: 1024,
        temperature: 0.1
      )

      parse_evaluation(response)
    end

    private

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
