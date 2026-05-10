module TutorSimulation
  class ReportGenerator
    # Per-profile indicative thresholds. Used only for WARN flags in the
    # markdown report — not enforced by CI. Calibrate from baseline runs.
    PER_PROFILE_THRESHOLDS = {
      "autonome" => {
        proactive_help_rate:               { op: :<=, value: 0.20 }.freeze,
        mean_help_steps_before_resolution: { op: :>=, value: 0.5 }.freeze,
        correction_view_rate:              { op: :==, value: 0.0 }.freeze
      }.freeze,
      "collaboratif" => {
        proactive_help_rate:               { op: :<=, value: 0.30 }.freeze,
        mean_help_steps_before_resolution: { op: :>=, value: 1.5 }.freeze,
        correct_attempts_after_help_rate:  { op: :>=, value: 0.60 }.freeze,
        correction_view_rate:              { op: :<=, value: 0.20 }.freeze
      }.freeze,
      "passif" => {
        proactive_help_rate:               { op: :<=, value: 0.50 }.freeze,
        mean_help_steps_before_resolution: { op: :>=, value: 1.0 }.freeze,
        correct_attempts_after_help_rate:  { op: :>=, value: 0.40 }.freeze,
        correction_view_rate:              { op: :>=, value: 0.66 }.freeze
      }.freeze
    }.freeze

    def initialize(simulation_data)
      @data = simulation_data
    end

    def to_json
      JSON.pretty_generate(@data)
    end

    def to_markdown
      lines = []
      lines << "# Simulation Tuteur — #{@data[:subject_title]}"
      lines << ""
      lines << "| | |"
      lines << "|---|---|"
      lines << "| **Date** | #{@data[:timestamp]} |"
      lines << "| **Tours max** | #{@data[:max_turns]} |"
      lines << "| **Tuteur** | #{@data[:tutor_provider]} / #{@data[:tutor_model]} |"
      lines << "| **Élève simulé** | #{@data[:student_provider]} / #{@data[:student_model]} |"
      lines << "| **Juge** | #{@data[:judge_provider]} / #{@data[:judge_model]} |"
      lines << ""

      @data[:results].each do |result|
        lines << "---"
        lines << ""
        lines << "## #{result[:question_number]} — #{result[:question_label]} (#{result[:points]} pts)"
        lines << ""

        result[:profiles].each do |profile_result|
          lines << "### Profil : #{profile_result[:profile_label]}"
          lines << ""

          render_structural(lines, profile_result[:structural_metrics], profile_result[:profile])
          render_qualitative(lines, profile_result[:evaluation])
          render_transcript(lines, profile_result[:transcript])
          lines << ""
        end
      end

      lines << "---"
      lines << ""
      lines << global_summary
      lines.join("\n")
    end

    private

    def render_structural(lines, metrics, profile = nil)
      return unless metrics

      lines << "**Métriques structurelles** (calculées sur la conversation persistée)"
      lines << ""
      lines << "| Métrique | Valeur |"
      lines << "|---|---|"
      lines << "| Taux de résolution (cible ≥0.7) | #{format_metric(metrics, :resolution_rate, profile)} |"
      lines << "| Violations CAP (cible = 0) | #{format_value(metrics[:cap_violations])} |"
      lines << "| Étapes d'aide avant résolution | #{format_metric(metrics, :mean_help_steps_before_resolution, profile)} |"
      lines << "| Taux aide proactive | #{format_metric(metrics, :proactive_help_rate, profile)} |"
      lines << "| Taux tentatives correctes après aide | #{format_metric(metrics, :correct_attempts_after_help_rate, profile)} |"
      lines << "| Tentatives par question | #{format_value(metrics[:attempts_per_question])} |"
      lines << "| Taux consultation correction | #{format_metric(metrics, :correction_view_rate, profile)} |"
      lines << "| Tours moyens avant résolution | #{format_value(metrics[:mean_turns_to_resolution])} |"
      lines << ""
    end

    def format_value(value)
      value.nil? ? "—" : value
    end

    def format_metric(metrics, key, profile)
      value = metrics[key]
      return "—" if value.nil?

      threshold = PER_PROFILE_THRESHOLDS.dig(profile.to_s, key)
      return value.to_s if threshold.nil?

      passes = case threshold[:op]
      when :<= then value <= threshold[:value]
      when :>= then value >= threshold[:value]
      when :== then value == threshold[:value]
      else
        raise ArgumentError, "Unknown threshold op: #{threshold[:op].inspect}"
      end

      passes ? value.to_s : "#{value} ⚠ WARN"
    end

    def render_qualitative(lines, evaluation)
      if evaluation&.key?("error")
        lines << "> ⚠ Erreur d'évaluation juge : #{evaluation['error']}"
        lines << ""
        return
      end

      if evaluation&.dig("skipped")
        lines << "> ⊙ Juge désactivé (SKIP_JUDGE=1) — évaluation qualitative non disponible."
        lines << ""
        return
      end

      return unless evaluation

      lines << "**Évaluation qualitative (juge LLM)**"
      lines << ""
      lines << "| Critère | Note | Justification |"
      lines << "|---|---|---|"

      Judge::CRITERIA.each do |criterion|
        key = criterion[:key].to_s
        next unless evaluation.key?(key)

        score = evaluation[key]["score"]
        justification = evaluation[key]["justification"]
        lines << "| #{criterion[:label]} | #{score}/5 | #{justification} |"
      end

      scores = Judge::CRITERIA.map { |c| evaluation.dig(c[:key].to_s, "score") }.compact
      avg = scores.any? ? (scores.sum.to_f / scores.size).round(1) : "N/A"
      lines << ""
      lines << "**Score moyen : #{avg}/5**"

      if evaluation.key?("synthese")
        lines << ""
        lines << "> #{evaluation['synthese']}"
      end
      lines << ""
    end

    def render_transcript(lines, transcript)
      lines << "<details><summary>Transcript (#{transcript.size} messages)</summary>"
      lines << ""
      transcript.each do |msg|
        role_label = msg["role"] == "user" ? "Élève" : "Tuteur"
        lines << "> **#{role_label}** : #{msg['content']}"
        lines << ""
      end
      lines << "</details>"
    end

    def global_summary
      qualitative_scores         = []
      resolution_rates           = []
      cap_violations_total       = []
      mean_help_steps            = []
      proactive_help_rates       = []
      correct_after_help_rates   = []
      attempts_per_q             = []
      correction_view_rates      = []
      mean_turns                 = []

      @data[:results].each do |result|
        result[:profiles].each do |pr|
          Judge::CRITERIA.each do |c|
            score = pr[:evaluation]&.dig(c[:key].to_s, "score")
            qualitative_scores << score if score
          end

          metrics = pr[:structural_metrics]
          next unless metrics

          resolution_rates         << metrics[:resolution_rate]         unless metrics[:resolution_rate].nil?
          cap_violations_total     << metrics[:cap_violations]          unless metrics[:cap_violations].nil?
          mean_help_steps          << metrics[:mean_help_steps_before_resolution] unless metrics[:mean_help_steps_before_resolution].nil?
          proactive_help_rates     << metrics[:proactive_help_rate]     unless metrics[:proactive_help_rate].nil?
          correct_after_help_rates << metrics[:correct_attempts_after_help_rate] unless metrics[:correct_attempts_after_help_rate].nil?
          attempts_per_q           << metrics[:attempts_per_question]   unless metrics[:attempts_per_question].nil?
          correction_view_rates    << metrics[:correction_view_rate]    unless metrics[:correction_view_rate].nil?
          mean_turns               << metrics[:mean_turns_to_resolution] unless metrics[:mean_turns_to_resolution].nil?
        end
      end

      lines = []
      lines << "## Résumé global"
      lines << ""

      if qualitative_scores.any?
        avg = (qualitative_scores.sum.to_f / qualitative_scores.size).round(2)
        lines << "**Qualitatif (juge LLM, 5 critères)**"
        lines << ""
        lines << "| Critère | Moyenne |"
        lines << "|---|---|"
        Judge::CRITERIA.each do |c|
          scores = collect_criterion_scores(c[:key].to_s)
          avg_c = scores.any? ? (scores.sum.to_f / scores.size).round(1) : "N/A"
          lines << "| #{c[:label]} | #{avg_c}/5 |"
        end
        lines << "| **Moyenne globale** | **#{avg}/5** |"
        lines << ""
      end

      if resolution_rates.any?
        avg_resolution = (resolution_rates.sum.to_f / resolution_rates.size).round(2)
        lines << "**Structurel (calculé sur les conversations)**"
        lines << ""
        lines << "| Métrique | Moyenne |"
        lines << "|---|---|"
        lines << "| Taux de résolution (cible ≥0.7) | #{avg_resolution} |"
        lines << "| Violations CAP (somme) | #{cap_violations_total.sum} |"
        lines << "| Étapes d'aide avant résolution | #{mean_help_steps.any? ? (mean_help_steps.sum.to_f / mean_help_steps.size).round(1) : "—"} |"
        lines << "| Taux aide proactive | #{proactive_help_rates.any? ? (proactive_help_rates.sum.to_f / proactive_help_rates.size).round(2) : "—"} |"
        lines << "| Taux tentatives correctes après aide | #{correct_after_help_rates.any? ? (correct_after_help_rates.sum.to_f / correct_after_help_rates.size).round(2) : "—"} |"
        lines << "| Tentatives par question | #{attempts_per_q.any? ? (attempts_per_q.sum.to_f / attempts_per_q.size).round(1) : "—"} |"
        lines << "| Taux consultation correction | #{correction_view_rates.any? ? (correction_view_rates.sum.to_f / correction_view_rates.size).round(2) : "—"} |"
        lines << "| Tours moyens avant résolution | #{mean_turns.any? ? (mean_turns.sum.to_f / mean_turns.size).round(1) : "—"} |"
        lines << ""
      end

      lines.join("\n")
    end

    def collect_criterion_scores(key)
      scores = []
      @data[:results].each do |result|
        result[:profiles].each do |pr|
          s = pr[:evaluation]&.dig(key, "score")
          scores << s if s
        end
      end
      scores
    end
  end
end
