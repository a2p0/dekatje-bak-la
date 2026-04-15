module Tutor
  module Tools
    class EvaluateSpottingTool < RubyLLM::Tool
      description <<~DESC.strip
        Conclure la phase de repérage (spotting) : success (l'élève a
        identifié les données, transition automatique vers guiding),
        failure (rester en spotting, relancer avec le niveau suivant),
        forced_reveal (après 3 échecs, révéler et passer en guiding).
        N'est appelable qu'en phase spotting.
      DESC

      param :outcome,
            type: :string,
            desc: "Résultat du repérage : success, failure ou forced_reveal",
            required: true

      def execute(outcome:)
        { ok: true, recorded: { outcome: outcome } }
      end
    end
  end
end
