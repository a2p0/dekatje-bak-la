module Tutor
  module Tools
    class UpdateLearnerModelTool < RubyLLM::Tool
      description <<~DESC.strip
        Mettre à jour le modèle de l'élève : concepts maîtrisés, concepts
        à revoir, niveau de découragement. Tous les paramètres sont
        optionnels — un appel vide est valide mais sans effet.
      DESC

      param :concept_mastered,
            type: :string,
            desc: "Concept que l'élève vient de démontrer maîtriser",
            required: false

      param :concept_to_revise,
            type: :string,
            desc: "Concept mal maîtrisé à réviser",
            required: false

      param :discouragement_delta,
            type: :integer,
            desc: "Variation du découragement (typique -1, 0, +1). Clampé [0, 3] côté serveur.",
            required: false

      def execute(concept_mastered: nil, concept_to_revise: nil, discouragement_delta: nil)
        {
          ok: true,
          recorded: {
            concept_mastered:     concept_mastered,
            concept_to_revise:    concept_to_revise,
            discouragement_delta: discouragement_delta
          }
        }
      end
    end
  end
end
