class EnrichStructuredCorrection
  Result = Struct.new(:ok, :structured_correction, :error, keyword_init: true) do
    def ok? = ok
  end

  SYSTEM_PROMPT = <<~PROMPT.freeze
    Tu es un assistant pédagogique spécialisé dans l'analyse de corrections d'examens BAC STI2D français.

    On te fournit la correction officielle d'une question. Ta tâche est de la décomposer en 4 catégories
    structurées afin qu'un tuteur IA puisse guider un élève SANS révéler la réponse finale.

    ## Structure attendue (OBLIGATOIRE — JSON pur, aucun texte autour)

    {
      "input_data": [
        {
          "name": "nom humain de la donnée (ex: 'épaisseur de la laine de roche')",
          "value": "valeur exacte avec son unité (ex: '0,18 m')",
          "source": "où l'élève trouve cette donnée — utiliser EXACTEMENT l'une de : 'DT<n>', 'DTS<n>', 'DR<n>', 'DRS<n>', 'question_context', 'mise_en_situation', 'question_precedente'"
        }
      ],
      "final_answers": [
        {
          "name": "nom humain du résultat à trouver (ex: 'résistance thermique de la laine de roche')",
          "value": "valeur ou réponse finale attendue (ex: '5,29 m²·K·W-1' pour un calcul, 'Polyuréthane' pour un choix qualitatif, 'Oui, le bâtiment respecte la RE 2020' pour une conclusion)",
          "reasoning": "formule appliquée OU raisonnement court menant à la réponse (ex: 'R = e/λ = 0,18/0,034' pour un calcul, 'Comparaison des bilans carbone du DTS3, la laine de roche a la valeur la plus élevée' pour une argumentation)"
        }
      ],
      "intermediate_steps": [
        "étape 1 du raisonnement attendu (phrase courte, impérative)",
        "étape 2 ...",
        "étape 3 ..."
      ],
      "common_errors": [
        {
          "error": "description courte d'une erreur fréquente",
          "remediation": "comment corriger ou éviter cette erreur (phrase courte)"
        }
      ]
    }

    ## Règles CRUCIALES

    1. **input_data vs final_answers** : le critère de séparation est "l'élève doit-il trouver cette valeur
       lui-même ou peut-il la lire directement ?".
       - Si la valeur est DANS le sujet (DT, DR, context, mise en situation) → input_data.
       - Si la valeur est le RÉSULTAT d'un calcul ou d'une démonstration demandée → final_answers.
       - Une valeur intermédiaire qu'il faut calculer à partir d'input_data est un final_answer aussi
         (parce que l'élève doit l'obtenir lui-même).

    2. **Exhaustivité d'input_data** : liste TOUTES les données d'entrée citées dans la correction,
       même si leur source n'est pas explicite — si tu inférais leur source depuis le contexte,
       indique-la au mieux ; à défaut, utilise "question_context" ou "mise_en_situation".

    3. **Exhaustivité de final_answers** : liste TOUS les résultats finaux ET intermédiaires-demandés.
       Si la question demande "calculer la résistance de chaque couche", chaque couche est un final_answer
       distinct.

    4. **intermediate_steps** : étapes de raisonnement AVEC les valeurs input_data mais SANS les
       final_answers. Par exemple "Appliquer R = e/λ pour chaque couche" — pas "Obtenir R = 5,29 pour
       la laine de roche".

    5. **common_errors** : 2 à 4 erreurs pédagogiquement pertinentes, tirées de l'analyse de la
       correction et du type de calcul. Inutile d'inventer si la correction ne donne pas d'indice.

    6. **Format des valeurs** : recopier verbatim depuis la correction (virgules françaises, unités
       exactes, exposants Unicode).

    7. **Retourne UNIQUEMENT le JSON**, sans markdown, sans phrase d'intro.
  PROMPT

  def self.call(answer:, api_key:, provider:)
    new(answer: answer, api_key: api_key, provider: provider).call
  end

  def initialize(answer:, api_key:, provider:)
    @answer   = answer
    @api_key  = api_key
    @provider = provider
  end

  def call
    client = AiClientFactory.build(provider: @provider, api_key: @api_key)
    raw = client.call(
      messages:    [ { role: "user", content: build_user_message(@answer) } ],
      system:      SYSTEM_PROMPT,
      max_tokens:  4096,
      temperature: 0.0
    )
    json = extract_json(raw)
    Result.new(ok: true, structured_correction: json, error: nil)
  rescue StandardError => e
    Result.new(ok: false, structured_correction: nil, error: e.message)
  end

  private

  def build_user_message(answer)
    question = answer.question

    <<~MSG
      Voici la question et sa correction officielle.

      === QUESTION ===
      Numéro : #{question.number}
      Énoncé : #{question.label}

      === CONTEXTE LOCAL DE LA QUESTION ===
      #{question.context_text.presence || '(aucun contexte additionnel)'}

      === DOCUMENTS RÉFÉRENCÉS ===
      DT/DTS : #{question.dt_references.join(', ').presence || '(aucun)'}
      DR/DRS : #{question.dr_references.join(', ').presence || '(aucun)'}

      === DATA HINTS (sources déjà identifiées) ===
      #{answer.data_hints.map { |h| "- #{h['source']} : #{h['location']}" }.join("\n").presence || '(aucun)'}

      === CORRECTION OFFICIELLE ===
      #{answer.correction_text}

      === EXPLICATION PÉDAGOGIQUE ===
      #{answer.explanation_text}

      === CONCEPTS CLÉS ===
      #{answer.key_concepts.join(', ').presence || '(aucun)'}

      Produis maintenant le JSON enrichi selon la structure demandée.
    MSG
  end

  def extract_json(raw)
    cleaned = raw.strip
    cleaned = cleaned.sub(/\A```(?:json)?\s*/i, "").sub(/```\s*\z/, "")
    match = cleaned.match(/\{.*\}/m)
    raise "Pas de JSON trouvé dans la réponse" unless match

    JSON.parse(match[0].gsub(/,(\s*[\]\}])/, '\1'))
  end
end
