# Juge absolu : GPT-5.5 note chaque extraction independamment (1-5 par critere).
# Pas de comparaison inter-modeles — chaque question est evaluee seule.
#
# Usage (via judge.rb) :
#   bin/rails runner evals/extraction/judge.rb <subject_id> --mode absolute
#
# Output : results/<subject_id>/absolute_report.json
#          results/<subject_id>/absolute_summary.md

require_relative "shared"

ABSOLUTE_SYSTEM = <<~PROMPT.freeze
  Tu es un expert en evaluation de systemes d'extraction de sujets d'examen BAC STI2D.
  On te presente une extraction JSON d'une question issue d'un sujet d'examen.
  Tu dois noter cette extraction sur 5 criteres, de 1 a 5.

  Les criteres sont :
  - completude : tous les elements sont-ils presents ? (label, points, references aux documents)
    1 = elements majeurs manquants, 5 = tout est present et complet
  - verbatim : le label et la correction sont-ils fideles au sujet original ?
    1 = forte paraphrase ou omissions importantes, 5 = copie exacte mot pour mot
  - data_hints : les references aux documents (source + location) sont-elles precises et utiles ?
    1 = absentes ou incorrectes, 5 = precises, bien localisees, directement utilisables par l'eleve
  - structure : le JSON respecte-t-il le schema attendu ? Champs corrects, types valides ?
    1 = schema invalide ou champs manquants, 5 = parfaitement conforme
  - pedagogique : l'explication est-elle claire, bien sourcee, raisonnee etape par etape ?
    1 = confuse ou incomplete, 5 = exemplaire, cite les sources, guide l'eleve efficacement

  Reponds en JSON valide avec cette structure exacte :
  {
    "completude":  { "score": 1-5, "reason": "explication courte" },
    "verbatim":    { "score": 1-5, "reason": "explication courte" },
    "data_hints":  { "score": 1-5, "reason": "explication courte" },
    "structure":   { "score": 1-5, "reason": "explication courte" },
    "pedagogique": { "score": 1-5, "reason": "explication courte" }
  }
  Aucun texte en dehors du JSON.
PROMPT

def build_single_prompt(question_number, extraction, model_label)
  <<~MSG
    ## Question #{question_number} — #{model_label}

    ```json
    #{JSON.pretty_generate(extraction)}
    ```

    Note cette extraction sur les 5 criteres.
  MSG
end

def run_absolute(subject_id, subject_dir, openrouter_key)
  data           = load_extractions(subject_dir)
  common_numbers = data[:common_numbers]
  only_opus      = data[:only_opus]
  only_mistral   = data[:only_mistral]

  results_opus    = []
  results_mistral = []
  total_cost       = 0.0
  total_tokens_in  = 0
  total_tokens_out = 0

  # Scores cumules : {modele => {critere => [scores]}}
  scores = {
    "opus"    => CRITERIA.index_with { [] },
    "mistral" => CRITERIA.index_with { [] }
  }

  total_questions = common_numbers.size * 2 + only_opus.size + only_mistral.size
  counter = 0

  common_numbers.each do |qnum|
    [
      ["opus",    data[:opus_by_number][qnum]],
      ["mistral", data[:mistral_by_number][qnum]]
    ].each do |model, extraction|
      counter += 1
      print "  [#{counter}/#{total_questions}] Q#{qnum} #{model}... "

      prompt = build_single_prompt(qnum, extraction, model.capitalize)

      begin
        result = call_openrouter(ABSOLUTE_SYSTEM, prompt, openrouter_key)
        total_cost       += result[:cost]
        total_tokens_in  += result[:tokens_in]
        total_tokens_out += result[:tokens_out]

        judgment = parse_json_response(result[:text])
        unless judgment
          puts "ERREUR JSON"
          (model == "opus" ? results_opus : results_mistral) <<
            { question_number: qnum, error: "JSON invalide : #{result[:text][0..120]}" }
          next
        end

        question_result = { question_number: qnum, model: model,
                            elapsed_s: result[:elapsed], cost_usd: format("%.5f", result[:cost]) }
        CRITERIA.each do |c|
          score  = judgment.dig(c, "score").to_i
          reason = judgment.dig(c, "reason").to_s
          scores[model][c] << score
          question_result["#{c}_score"]  = score
          question_result["#{c}_reason"] = reason
        end

        (model == "opus" ? results_opus : results_mistral) << question_result
        print "OK (#{result[:elapsed]}s)\n"
      rescue => e
        puts "ERREUR : #{e.message}"
        (model == "opus" ? results_opus : results_mistral) <<
          { question_number: qnum, model: model, error: e.message }
      end
    end
  end

  # Calcul des moyennes
  averages = {}
  %w[opus mistral].each do |model|
    averages[model] = CRITERIA.each_with_object({}) do |c, h|
      vals = scores[model][c].reject(&:zero?)
      h[c] = vals.empty? ? nil : (vals.sum.to_f / vals.size).round(2)
    end
    averages[model]["global"] = begin
      all = CRITERIA.filter_map { |c| averages[model][c] }
      all.empty? ? nil : (all.sum / all.size).round(2)
    end
  end

  # --- Sauvegarde JSON ---
  report = {
    subject_id:      subject_id,
    mode:            "absolute",
    judge_model:     JUDGE_MODEL,
    generated_at:    Time.now.iso8601,
    questions_judged: common_numbers.size,
    only_in_opus:    only_opus,
    only_in_mistral: only_mistral,
    total_cost_usd:  format("%.4f", total_cost),
    total_tokens:    { in: total_tokens_in, out: total_tokens_out },
    averages:        averages,
    details:         { opus: results_opus, mistral: results_mistral }
  }
  report_path = subject_dir.join("absolute_report.json")
  File.write(report_path, JSON.pretty_generate(report))

  # --- Rapport Markdown ---
  summary_path = subject_dir.join("absolute_summary.md")
  File.open(summary_path, "w") do |f|
    f.puts "# Jugement absolu — Sujet ##{subject_id}"
    f.puts ""
    f.puts "Juge : `#{JUDGE_MODEL}` | #{common_numbers.size} questions | Cout : $#{format("%.4f", total_cost)}"
    f.puts ""
    f.puts "## Moyennes par critere (1-5)"
    f.puts ""
    f.puts "| Critere | Opus | Mistral | Delta |"
    f.puts "|---------|------|---------|-------|"
    CRITERIA.each do |c|
      o = averages["opus"][c]
      m = averages["mistral"][c]
      delta = o && m ? format("%+.2f", o - m) : "n/a"
      f.puts "| #{c} | #{o || "n/a"} | #{m || "n/a"} | #{delta} |"
    end
    og = averages["opus"]["global"]
    mg = averages["mistral"]["global"]
    delta_g = og && mg ? format("%+.2f", og - mg) : "n/a"
    f.puts "| **global** | **#{og || "n/a"}** | **#{mg || "n/a"}** | **#{delta_g}** |"
    f.puts ""
    f.puts "## Detail par question"
    f.puts ""
    common_numbers.each do |qnum|
      f.puts "### Q#{qnum}"
      %w[opus mistral].each do |model|
        r = (model == "opus" ? results_opus : results_mistral).find { |x| x[:question_number] == qnum }
        next unless r
        if r[:error]
          f.puts "- **#{model.capitalize}** : ERREUR #{r[:error]}"
        else
          scores_str = CRITERIA.map { |c| "#{c}=#{r["#{c}_score"]}" }.join(", ")
          f.puts "- **#{model.capitalize}** : #{scores_str}"
        end
      end
      f.puts ""
    end
  end

  # Resume terminal
  puts "\n#{"=" * 60}"
  puts "ABSOLU — RESUME (moyennes /5)"
  puts "=" * 60
  puts "| Critere      | Opus | Mistral | Delta |"
  puts "|--------------|------|---------|-------|"
  CRITERIA.each do |c|
    o = averages["opus"][c] || "n/a"
    m = averages["mistral"][c] || "n/a"
    d = averages["opus"][c] && averages["mistral"][c] ? format("%+.2f", averages["opus"][c] - averages["mistral"][c]) : "n/a"
    puts "| #{c.ljust(12)} | #{o.to_s.center(4)} | #{m.to_s.center(7)} | #{d.center(5)} |"
  end
  og = averages["opus"]["global"] || "n/a"
  mg = averages["mistral"]["global"] || "n/a"
  dg = averages["opus"]["global"] && averages["mistral"]["global"] ? format("%+.2f", averages["opus"]["global"] - averages["mistral"]["global"]) : "n/a"
  puts "| #{"global".ljust(12)} | #{og.to_s.center(4)} | #{mg.to_s.center(7)} | #{dg.center(5)} |"
  puts "\nCout  : $#{format("%.4f", total_cost)} (#{total_tokens_in} in / #{total_tokens_out} out)"
  puts "\nRapport JSON : #{report_path}"
  puts "Rapport MD   : #{summary_path}"
end
