module TutorSimulation
  class ReportGenerator
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

          render_structural(lines, profile_result[:structural_metrics])
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

    def render_structural(lines, metrics)
      return unless metrics

      lines << "**Métriques structurelles** (calculées sur la conversation persistée)"
      lines << ""
      lines << "| Métrique | Valeur |"
      lines << "|---|---|"
      lines << "| Phase finale | `#{metrics[:final_phase]}` (rang #{metrics[:phase_rank]}/7) |"
      lines << "| Mots / message tuteur (cible ≤60) | #{metrics[:avg_message_length_words]} |"
      lines << "| Ratio messages se terminant par `?` (cible ≥0.7) | #{metrics[:open_question_ratio]} |"
      lines << "| Interceptions filtre regex (low = bon) | #{metrics[:regex_intercepts]} |"
      lines << "| Indices distribués | #{metrics[:hints_used]} |"
      lines << "| Messages assistant / élève | #{metrics[:message_count_assistant]} / #{metrics[:message_count_user]} |"
      lines << "| 1er tour avec transition (H1) | #{format_value(metrics[:first_turn_with_transition])} |"
      lines << "| % verbes d'action en guiding (H2) | #{format_value(metrics[:action_verb_ratio_guiding])} |"
      lines << "| Leaks DT/DR hors spotting | #{metrics[:dt_dr_leak_count_non_spotting]} |"
      lines << "| % messages ≤ 60 mots (cible ≥0.7) | #{metrics[:short_message_ratio]} |"
      lines << ""
    end

    def format_value(value)
      value.nil? ? "—" : value
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
      qualitative_scores   = []
      phase_ranks          = []
      open_q_ratios        = []
      regex_intercepts     = []
      first_turns          = []
      action_verb_ratios   = []
      dt_dr_leaks          = []
      short_msg_ratios     = []

      @data[:results].each do |result|
        result[:profiles].each do |pr|
          Judge::CRITERIA.each do |c|
            score = pr[:evaluation]&.dig(c[:key].to_s, "score")
            qualitative_scores << score if score
          end

          metrics = pr[:structural_metrics]
          next unless metrics

          phase_ranks      << metrics[:phase_rank]
          open_q_ratios    << metrics[:open_question_ratio]
          regex_intercepts << metrics[:regex_intercepts]
          first_turns          << metrics[:first_turn_with_transition] unless metrics[:first_turn_with_transition].nil?
          action_verb_ratios   << metrics[:action_verb_ratio_guiding]  unless metrics[:action_verb_ratio_guiding].nil?
          dt_dr_leaks          << metrics[:dt_dr_leak_count_non_spotting] if metrics.key?(:dt_dr_leak_count_non_spotting)
          short_msg_ratios     << metrics[:short_message_ratio]        if metrics.key?(:short_message_ratio)
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

      if phase_ranks.any?
        lines << "**Structurel (calculé sur les conversations)**"
        lines << ""
        lines << "| Métrique | Moyenne |"
        lines << "|---|---|"
        lines << "| Phase finale moyenne (rang/7) | #{(phase_ranks.sum.to_f / phase_ranks.size).round(1)} |"
        lines << "| Ratio questions ouvertes | #{(open_q_ratios.sum.to_f / open_q_ratios.size).round(2)} |"
        lines << "| Interceptions regex (somme) | #{regex_intercepts.sum} |"
        lines << "| 1er tour transition moyen (H1, non-nil) | #{first_turns.any? ? (first_turns.sum.to_f / first_turns.size).round(1) : "—"} |"
        lines << "| % verbes d'action moyen (H2, non-nil) | #{action_verb_ratios.any? ? (action_verb_ratios.sum.to_f / action_verb_ratios.size).round(2) : "—"} |"
        lines << "| Leaks DT/DR totaux | #{dt_dr_leaks.sum} |"
        lines << "| % messages ≤ 60 mots moyen | #{short_msg_ratios.any? ? (short_msg_ratios.sum.to_f / short_msg_ratios.size).round(2) : "—"} |"
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
