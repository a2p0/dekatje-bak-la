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

def run_absolute(subject_id, subject_dir, openrouter_key, model_a: "opus", model_b: "mistral")
  data           = load_extractions(subject_dir, model_a: model_a, model_b: model_b)
  common_numbers = data[:common_numbers]
  only_opus      = data[:only_opus]
  only_mistral   = data[:only_mistral]
  model_a        = data[:model_a]
  model_b        = data[:model_b]

  results_a        = []
  results_b        = []
  total_cost       = 0.0
  total_tokens_in  = 0
  total_tokens_out = 0

  # Scores cumules : {modele => {critere => [scores]}}
  scores = {
    model_a => CRITERIA.index_with { [] },
    model_b => CRITERIA.index_with { [] }
  }

  total_questions = common_numbers.size * 2 + only_opus.size + only_mistral.size
  counter = 0

  common_numbers.each do |qnum|
    [
      [model_a, data[:opus_by_number][qnum]],
      [model_b, data[:mistral_by_number][qnum]]
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
          (model == model_a ? results_a : results_b) <<
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

        (model == model_a ? results_a : results_b) << question_result
        print "OK (#{result[:elapsed]}s)\n"
      rescue => e
        puts "ERREUR : #{e.message}"
        (model == model_a ? results_a : results_b) <<
          { question_number: qnum, model: model, error: e.message }
      end
    end
  end

  # Calcul des moyennes
  averages = {}
  [model_a, model_b].each do |model|
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
  slug = "#{model_a}_vs_#{model_b}"
  report = {
    subject_id:       subject_id,
    mode:             "absolute",
    model_a:          model_a,
    model_b:          model_b,
    judge_model:      JUDGE_MODEL,
    generated_at:     Time.now.iso8601,
    questions_judged: common_numbers.size,
    only_in_a:        only_opus,
    only_in_b:        only_mistral,
    total_cost_usd:   format("%.4f", total_cost),
    total_tokens:     { in: total_tokens_in, out: total_tokens_out },
    averages:         averages,
    details:          { model_a => results_a, model_b => results_b }
  }
  report_path = subject_dir.join("absolute_#{slug}_report.json")
  File.write(report_path, JSON.pretty_generate(report))

  # --- Rapport Markdown ---
  summary_path = subject_dir.join("absolute_#{slug}_summary.md")
  File.open(summary_path, "w") do |f|
    f.puts "# Jugement absolu — Sujet ##{subject_id} — #{model_a} vs #{model_b}"
    f.puts ""
    f.puts "Juge : `#{JUDGE_MODEL}` | #{common_numbers.size} questions | Cout : $#{format("%.4f", total_cost)}"
    f.puts ""
    f.puts "## Moyennes par critere (1-5)"
    f.puts ""
    f.puts "| Critere | #{model_a} | #{model_b} | Delta (A-B) |"
    f.puts "|---------|#{"-" * (model_a.length + 2)}|#{"-" * (model_b.length + 2)}|-------------|"
    CRITERIA.each do |c|
      a = averages[model_a][c]
      b = averages[model_b][c]
      delta = a && b ? format("%+.2f", a - b) : "n/a"
      f.puts "| #{c} | #{a || "n/a"} | #{b || "n/a"} | #{delta} |"
    end
    ag = averages[model_a]["global"]
    bg = averages[model_b]["global"]
    delta_g = ag && bg ? format("%+.2f", ag - bg) : "n/a"
    f.puts "| **global** | **#{ag || "n/a"}** | **#{bg || "n/a"}** | **#{delta_g}** |"
    f.puts ""
    f.puts "## Detail par question"
    f.puts ""
    common_numbers.each do |qnum|
      f.puts "### Q#{qnum}"
      [[model_a, results_a], [model_b, results_b]].each do |model, results|
        r = results.find { |x| x[:question_number] == qnum }
        next unless r
        if r[:error]
          f.puts "- **#{model}** : ERREUR #{r[:error]}"
        else
          scores_str = CRITERIA.map { |c| "#{c}=#{r["#{c}_score"]}" }.join(", ")
          f.puts "- **#{model}** : #{scores_str}"
        end
      end
      f.puts ""
    end
  end

  # Resume terminal
  puts "\n#{"=" * 60}"
  puts "ABSOLU — RESUME (moyennes /5)"
  puts "=" * 60
  puts "| Critere      | #{model_a.ljust(20)} | #{model_b.ljust(20)} | Delta |"
  puts "|--------------|#{"-" * 22}|#{"-" * 22}|-------|"
  CRITERIA.each do |c|
    a = averages[model_a][c] || "n/a"
    b = averages[model_b][c] || "n/a"
    d = averages[model_a][c] && averages[model_b][c] ? format("%+.2f", averages[model_a][c] - averages[model_b][c]) : "n/a"
    puts "| #{c.ljust(12)} | #{a.to_s.center(22)} | #{b.to_s.center(22)} | #{d.center(5)} |"
  end
  ag = averages[model_a]["global"] || "n/a"
  bg = averages[model_b]["global"] || "n/a"
  dg = averages[model_a]["global"] && averages[model_b]["global"] ? format("%+.2f", averages[model_a]["global"] - averages[model_b]["global"]) : "n/a"
  puts "| #{"global".ljust(12)} | #{ag.to_s.center(22)} | #{bg.to_s.center(22)} | #{dg.center(5)} |"
  puts "\nCout  : $#{format("%.4f", total_cost)} (#{total_tokens_in} in / #{total_tokens_out} out)"
  puts "\nRapport JSON : #{report_path}"
  puts "Rapport MD   : #{summary_path}"
end
