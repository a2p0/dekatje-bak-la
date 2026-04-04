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

          evaluation = profile_result[:evaluation]
          if evaluation&.key?("error")
            lines << "> Erreur d'évaluation : #{evaluation['error']}"
            lines << ""
          else
            lines << "| Critère | Note | Justification |"
            lines << "|---|---|---|"

            Judge::CRITERIA.each do |criterion|
              key = criterion[:key].to_s
              if evaluation&.key?(key)
                score = evaluation[key]["score"]
                justification = evaluation[key]["justification"]
                lines << "| #{criterion[:label]} | #{score}/5 | #{justification} |"
              end
            end

            scores = Judge::CRITERIA.map { |c| evaluation&.dig(c[:key].to_s, "score") }.compact
            avg = scores.any? ? (scores.sum.to_f / scores.size).round(1) : "N/A"
            lines << ""
            lines << "**Score moyen : #{avg}/5**"

            if evaluation&.key?("synthese")
              lines << ""
              lines << "> #{evaluation['synthese']}"
            end
          end

          lines << ""
          lines << "<details><summary>Transcript (#{profile_result[:transcript].size} messages)</summary>"
          lines << ""

          profile_result[:transcript].each do |msg|
            role_label = msg["role"] == "user" ? "Élève" : "Tuteur"
            lines << "> **#{role_label}** : #{msg['content']}"
            lines << ""
          end

          lines << "</details>"
          lines << ""
        end
      end

      lines << "---"
      lines << ""
      lines << global_summary
      lines.join("\n")
    end

    private

    def global_summary
      all_scores = []
      @data[:results].each do |result|
        result[:profiles].each do |pr|
          Judge::CRITERIA.each do |c|
            score = pr[:evaluation]&.dig(c[:key].to_s, "score")
            all_scores << score if score
          end
        end
      end

      return "## Résumé global\n\nAucune évaluation disponible." if all_scores.empty?

      avg = (all_scores.sum.to_f / all_scores.size).round(2)
      min = all_scores.min
      max = all_scores.max

      per_criterion = Judge::CRITERIA.map do |c|
        scores = []
        @data[:results].each do |result|
          result[:profiles].each do |pr|
            s = pr[:evaluation]&.dig(c[:key].to_s, "score")
            scores << s if s
          end
        end
        avg_c = scores.any? ? (scores.sum.to_f / scores.size).round(1) : "N/A"
        "| #{c[:label]} | #{avg_c}/5 |"
      end

      lines = []
      lines << "## Résumé global"
      lines << ""
      lines << "| Métrique | Valeur |"
      lines << "|---|---|"
      lines << "| Score moyen global | **#{avg}/5** |"
      lines << "| Score min | #{min}/5 |"
      lines << "| Score max | #{max}/5 |"
      lines << ""
      lines << "### Moyennes par critère"
      lines << ""
      lines << "| Critère | Moyenne |"
      lines << "|---|---|"
      lines.concat(per_criterion)
      lines.join("\n")
    end
  end
end
