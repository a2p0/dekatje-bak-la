module Tutor
  module Tools
    class RequestHintTool < RubyLLM::Tool
      description <<~DESC.strip
        Demander un indice gradué pour la question courante. Toujours
        commencer par level: 1 et progresser 1→2→3… strictement
        monotone. Maximum 5. Les sauts sont refusés côté serveur.
      DESC

      param :level,
            type: :integer,
            desc: "Niveau d'indice entre 1 et 5, strictement monotone",
            required: true

      def execute(level:)
        { ok: true, recorded: { level: level } }
      end
    end
  end
end
