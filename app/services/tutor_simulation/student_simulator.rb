module TutorSimulation
  class StudentSimulator
    # 062: only :collaboratif retained. autonome and passif deferred to PR 063.
    PROFILES = {
      collaboratif: {
        label: "Élève collaboratif",
        system: <<~PROMPT
          Tu simules un élève de Terminale STI2D qui prépare le BAC.
          Profil : collaboratif — tu tentes d'abord de répondre par toi-même, puis tu demandes
          de l'aide de façon progressive : d'abord la formule à utiliser, puis une valeur, puis
          le calcul. Si tu es bloqué depuis plusieurs échanges, tu demandes à voir la correction.
          Tu préfères des messages courts, style SMS ou chips : "Quelle formule je dois utiliser ?",
          "Donne-moi un indice…", "Je ne vois pas comment partir."
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
        messages = [ { role: "user", content: "Voici la question : #{question_label}\nEssaie d'y répondre." } ]
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
