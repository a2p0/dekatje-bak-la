module TutorSimulation
  # Encapsulates per-profile runtime behavior used by the simulation Runner
  # — deciding when to trigger `viewed_correction` and whether to honor the
  # `[VOIR_CORRECTION]` tag a simulated student may emit.
  #
  # Profiles' personality (their LLM system prompt) lives in StudentSimulator.
  # ProfileBehavior is purely the deterministic side-channel that the Runner
  # uses to route the simulated student's behavior into trace events.
  class ProfileBehavior
    BEHAVIORS = {
      autonome: {
        view_correction_after_turns: nil,   # never triggers correction
        honor_view_tag:              false  # ignores [VOIR_CORRECTION]
      },
      collaboratif: {
        view_correction_after_turns: 8,
        honor_view_tag:              true
      },
      passif: {
        view_correction_after_turns: 3,
        honor_view_tag:              true
      }
    }.freeze

    VIEW_TAG = "[VOIR_CORRECTION]".freeze

    def self.for(profile)
      new(profile)
    end

    def initialize(profile)
      @profile = profile.to_sym
      @config  = BEHAVIORS.fetch(@profile)
    end

    def should_view_correction?(student_message:, turns_without_correct:)
      return true if @config[:honor_view_tag] && student_message.to_s.include?(VIEW_TAG)

      threshold = @config[:view_correction_after_turns]
      return false if threshold.nil?
      turns_without_correct >= threshold
    end

    def strip_view_tag(student_message)
      student_message.to_s.gsub(VIEW_TAG, "").strip
    end
  end
end
