module Tutor
  module Tools
    class TransitionTool < RubyLLM::Tool
      description <<~DESC.strip
        Changer la phase pédagogique courante de la conversation.
        À appeler systématiquement lors d'un changement de phase.
        Transitions autorisées : idle→greeting, greeting→enonce,
        enonce→spotting_type|guiding, spotting_type→spotting_data|guiding,
        spotting_data→guiding, guiding→validating|enonce,
        validating→feedback|ended, feedback→ended.
      DESC

      param :phase,
            type: :string,
            desc: "Phase cible (greeting, enonce, spotting_type, spotting_data, guiding, validating, feedback, ended)",
            required: true

      param :question_id,
            type: :integer,
            desc: "ID de la question associée (requis pour guiding et spotting)",
            required: false

      def name
        "transition"
      end

      def execute(phase:, question_id: nil)
        { ok: true, recorded: { phase: phase, question_id: question_id } }
      end
    end
  end
end
