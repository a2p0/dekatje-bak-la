class BuildExtractionPrompt
  SYSTEM_PROMPT = <<~PROMPT.freeze
    Tu es un assistant spécialisé dans l'analyse de sujets d'examens BAC STI2D français.
    Analyse le texte fourni et extrais toutes les informations structurées.

    Retourne UNIQUEMENT un objet JSON valide avec cette structure exacte :
    {
      "presentation": "Mise en situation générale du sujet",
      "parts": [
        {
          "number": 1,
          "title": "Titre de la partie",
          "objective": "Objectif pédagogique",
          "section_type": "common",
          "questions": [
            {
              "number": "1.1",
              "label": "Énoncé complet de la question",
              "context": "Contexte local ou données spécifiques (peut être vide)",
              "points": 2,
              "answer_type": "calculation",
              "correction": "Réponse officielle",
              "explanation": "Explication pédagogique",
              "data_hints": [
                {"source": "DT", "location": "description précise de l'emplacement"}
              ],
              "key_concepts": ["concept1", "concept2"]
            }
          ]
        }
      ]
    }

    Règles :
    - section_type : "common" (partie commune) ou "specific" (partie spécifique par spécialité)
    - answer_type : "text", "calculation", "argumentation", "dr_reference", "completion", "choice"
    - data_hints.source : "DT", "DR", "enonce", "question_context"
    - Ne retourne AUCUN texte en dehors du JSON
    - Si une information est manquante, utilise une chaîne vide "" ou un tableau vide []
  PROMPT

  def self.call(text:)
    {
      system: SYSTEM_PROMPT,
      messages: [
        {
          role: "user",
          content: "Voici le texte du sujet BAC à analyser :\n\n#{text}"
        }
      ]
    }
  end
end
