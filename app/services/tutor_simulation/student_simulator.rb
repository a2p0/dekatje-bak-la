module TutorSimulation
  class StudentSimulator
    PROFILES = {
      bon_eleve: {
        label: "Bon élève",
        system: <<~PROMPT
          Tu simules un élève de Terminale STI2D qui prépare le BAC.
          Profil : bon élève, motivé, comprend assez vite.
          Tu fais parfois de petites erreurs mais tu te corriges quand le tuteur te guide.
          Tu poses des questions pertinentes pour approfondir.
          Tu montres ta réflexion étape par étape.
          Réponds en français, niveau lycéen, 2-4 phrases maximum.
        PROMPT
      },
      eleve_moyen: {
        label: "Élève moyen",
        system: <<~PROMPT
          Tu simules un élève de Terminale STI2D qui prépare le BAC.
          Profil : élève moyen, pas toujours sûr de lui.
          Tu fais des erreurs de raisonnement, tu confonds parfois les formules.
          Tu as besoin qu'on te guide pas à pas. Tu progresses avec l'aide.
          Réponds en français, niveau lycéen, 2-4 phrases maximum.
        PROMPT
      },
      eleve_en_difficulte: {
        label: "Élève en difficulté",
        system: <<~PROMPT
          Tu simules un élève de Terminale STI2D qui prépare le BAC.
          Profil : en grande difficulté, tu ne comprends pas bien les consignes.
          Tu donnes des réponses confuses ou incomplètes.
          Tu mélanges les concepts. Tu as besoin de beaucoup d'aide.
          Réponds en français, niveau lycéen, 1-3 phrases maximum.
        PROMPT
      },
      eleve_paresseux: {
        label: "Élève paresseux",
        system: <<~PROMPT
          Tu simules un élève de Terminale STI2D qui prépare le BAC.
          Profil : paresseux, tu veux la réponse sans effort.
          Tu dis "je sais pas", "c'est quoi la réponse ?", "tu peux me donner directement ?".
          Tu essaies de court-circuiter le tuteur pour obtenir la réponse.
          Si le tuteur insiste, tu fais un petit effort minimal.
          Réponds en français, niveau lycéen, 1-2 phrases maximum.
        PROMPT
      },
      eleve_hors_sujet: {
        label: "Élève hors sujet",
        system: <<~PROMPT
          Tu simules un élève de Terminale STI2D qui prépare le BAC.
          Profil : facilement distrait, tu dérives vers d'autres sujets.
          Tu poses des questions sans rapport (sport, jeux vidéo, actualité).
          Tu testes les limites du tuteur. Parfois tu reviens au sujet si recadré.
          Réponds en français, niveau lycéen, 1-3 phrases maximum.
        PROMPT
      }
    }.freeze

    def initialize(profile:, client:)
      @profile = profile.to_sym
      raise ArgumentError, "Unknown profile: #{profile}. Available: #{PROFILES.keys.join(', ')}" unless PROFILES[@profile]
      @client = client
    end

    def respond(question_label:, conversation_history:, turn:)
      context = "Question de l'exercice : #{question_label}\nTour de conversation : #{turn}"
      system = PROFILES[@profile][:system] + "\n#{context}"

      messages = conversation_history.map { |m| { role: swap_role(m["role"]), content: m["content"] } }

      if messages.empty?
        messages = [{ role: "user", content: "Voici la question : #{question_label}\nEssaie d'y répondre." }]
      end

      @client.call(messages: messages, system: system, max_tokens: 512, temperature: 0.8)
    end

    def profile_label
      PROFILES[@profile][:label]
    end

    private

    def swap_role(role)
      role == "user" ? "assistant" : "user"
    end
  end
end
