class BuildExtractionPrompt
  SYSTEM_PROMPT = <<~PROMPT.freeze
    Tu es un assistant spécialisé dans l'analyse de sujets d'examens BAC STI2D français.
    Analyse le sujet et son corrigé pour extraire toutes les informations structurées.

    Le BAC STI2D comporte deux types de parties :
    - Les parties communes (common) valent environ 12 points et sont identiques pour toutes les spécialités.
    - Les parties spécifiques (specific) valent environ 8 points et dépendent de la spécialité de l'élève.

    Tu dois croiser chaque question avec sa correction pour produire une réponse complète.

    Identifie tous les Documents Techniques (DT) et Documents Réponses (DR) référencés,
    en notant les numéros de page où ils apparaissent dans le sujet.

    Retourne UNIQUEMENT un objet JSON valide, sans aucun texte autour, avec cette structure :
    {
      "metadata": {
        "title": "Titre du sujet",
        "year": 2024,
        "exam_type": "bac",
        "specialty": "ITEC"
      },
      "presentation": "Mise en situation générale du sujet",
      "common_parts": [
        {
          "number": 1,
          "title": "Titre de la partie commune",
          "objective": "Objectif pédagogique",
          "questions": [
            {
              "number": "1.1",
              "label": "Énoncé complet de la question",
              "context": "Contexte local ou données spécifiques (peut être vide)",
              "points": 2,
              "answer_type": "calculation",
              "dt_references": ["DT1", "DT2"],
              "dr_references": ["DR1"],
              "correction": "Réponse officielle extraite du corrigé",
              "explanation": "Explication pédagogique",
              "data_hints": [
                {"source": "DT", "location": "description précise de l'emplacement"},
                {"source": "DR", "location": "tableau à compléter"},
                {"source": "enonce", "location": "valeur donnée dans l'énoncé"},
                {"source": "question_context", "location": "donnée dans le contexte local"}
              ],
              "key_concepts": ["concept1", "concept2"]
            }
          ]
        }
      ],
      "specific_parts": [
        {
          "number": 3,
          "title": "Titre de la partie spécifique",
          "objective": "Objectif pédagogique",
          "questions": [
            {
              "number": "3.1",
              "label": "Énoncé complet",
              "context": "",
              "points": 2,
              "answer_type": "text",
              "dt_references": [],
              "dr_references": [],
              "correction": "Réponse officielle",
              "explanation": "Explication pédagogique",
              "data_hints": [],
              "key_concepts": []
            }
          ]
        }
      ],
      "document_references": {
        "common_dts": [
          {"label": "DT1", "title": "Titre du document technique", "pages": [3, 4]}
        ],
        "common_drs": [
          {"label": "DR1", "title": "Titre du document réponse", "pages": [10]}
        ],
        "specific_dts": [
          {"label": "DT5", "title": "Document technique spécifique", "pages": [7]}
        ],
        "specific_drs": [
          {"label": "DR3", "title": "Document réponse spécifique", "pages": [12]}
        ]
      }
    }

    Règles :
    - answer_type : "text", "calculation", "argumentation", "dr_reference", "completion", "choice"
    - data_hints.source : "DT", "DR", "enonce", "question_context"
    - Ne retourne AUCUN texte en dehors du JSON
    - Si une information est manquante, utilise une chaîne vide "" ou un tableau vide []
  PROMPT

  def self.call(subject_text:, correction_text:, specialty:)
    {
      system: SYSTEM_PROMPT,
      messages: [
        {
          role: "user",
          content: <<~MSG
            Spécialité de l'élève : #{specialty}

            === SUJET DE L'EXAMEN ===
            #{subject_text}

            === CORRIGÉ OFFICIEL ===
            #{correction_text}

            Analyse le sujet et le corrigé ci-dessus pour la spécialité #{specialty}.
            Extrais toutes les parties communes et spécifiques avec leurs questions, corrections et références aux documents.
          MSG
        }
      ]
    }
  end
end
