# Juge pairwise : GPT-5.5 compare Opus vs Mistral question par question
# sur 5 criteres, sans connaitre l'identite des modeles (blind).
#
# Usage (via judge.rb) :
#   bin/rails runner evals/extraction/judge.rb <subject_id> --mode pairwise
#
# Output : results/<subject_id>/pairwise_report.json
#          results/<subject_id>/pairwise_summary.md

require_relative "shared"

PAIRWISE_SYSTEM = <<~PROMPT.freeze
  Tu es un juge expert en evaluation de systemes d'extraction de sujets d'examen BAC STI2D.
  On te presente deux extractions JSON du meme sujet, produites par deux systemes differents.
  Tu dois comparer les deux extractions sur 5 criteres, question par question.

  Les criteres sont :
  - completude : la question est-elle entierement presente ? Aucun element manquant (label, points, references) ?
  - verbatim : le label et la correction sont-ils copies mot pour mot depuis le sujet original ? Pas de paraphrase, pas d'omission.
  - data_hints : les references aux documents (source + location) sont-elles precises, correctes et utiles pour l'eleve ?
  - structure : le JSON respecte-t-il le schema attendu ? Types corrects, champs presents, format valide ?
  - pedagogique : l'explication est-elle claire, bien sourcee, avec citations exactes et raisonnement etape par etape ?

  Pour chaque critere, reponds UNIQUEMENT avec "A", "B" ou "egalite".
  Tu ne connais pas l'identite des deux systemes. Juge uniquement sur la qualite du contenu.

  Reponds en JSON valide avec cette structure exacte :
  {
    "completude":  { "winner": "A"|"B"|"egalite", "reason": "explication courte" },
    "verbatim":    { "winner": "A"|"B"|"egalite", "reason": "explication courte" },
    "data_hints":  { "winner": "A"|"B"|"egalite", "reason": "explication courte" },
    "structure":   { "winner": "A"|"B"|"egalite", "reason": "explication courte" },
    "pedagogique": { "winner": "A"|"B"|"egalite", "reason": "explication courte" }
  }
  Aucun texte en dehors du JSON.
PROMPT

def run_pairwise(subject_id, subject_dir, openrouter_key)
  data = load_extractions(subject_dir)
  common_numbers = data[:common_numbers]
  only_opus      = data[:only_opus]
  only_mistral   = data[:only_mistral]

  judge_results    = []
  total_cost       = 0.0
  total_tokens_in  = 0
  total_tokens_out = 0

  scores = {
    "opus"    => CRITERIA.index_with(0),
    "mistral" => CRITERIA.index_with(0),
    "egalite" => CRITERIA.index_with(0)
  }

  common_numbers.each_with_index do |qnum, idx|
    print "  [#{idx + 1}/#{common_numbers.size}] Q#{qnum}... "

    # Alterne l'ordre pour limiter le biais de position
    if idx.even?
      extraction_a, extraction_b = data[:opus_by_number][qnum], data[:mistral_by_number][qnum]
      a_is, b_is = "opus", "mistral"
    else
      extraction_a, extraction_b = data[:mistral_by_number][qnum], data[:opus_by_number][qnum]
      a_is, b_is = "mistral", "opus"
    end

    prompt = build_question_prompt(qnum, extraction_a, extraction_b) +
             "\nCompare ces deux extractions sur les 5 criteres."

    begin
      result   = call_openrouter(PAIRWISE_SYSTEM, prompt, openrouter_key)
      total_cost       += result[:cost]
      total_tokens_in  += result[:tokens_in]
      total_tokens_out += result[:tokens_out]

      judgment = parse_json_response(result[:text])
      unless judgment
        puts "ERREUR JSON"
        judge_results << { question_number: qnum, error: "JSON invalide : #{result[:text][0..120]}" }
        next
      end

      question_result = { question_number: qnum, a_is: a_is, b_is: b_is,
                          elapsed_s: result[:elapsed], cost_usd: format("%.5f", result[:cost]) }

      CRITERIA.each do |c|
        raw    = judgment.dig(c, "winner").to_s.downcase
        reason = judgment.dig(c, "reason").to_s
        winner = case raw
                 when "a"       then a_is
                 when "b"       then b_is
                 when "egalite" then "egalite"
                 else "inconnu"
                 end
        scores[winner][c] += 1 if scores.key?(winner)
        question_result["#{c}_winner"] = winner
        question_result["#{c}_reason"] = reason
      end

      judge_results << question_result
      print "OK (#{result[:elapsed]}s)\n"
    rescue => e
      puts "ERREUR : #{e.message}"
      judge_results << { question_number: qnum, error: e.message }
    end
  end

  # Questions uniquement dans un modele → victoire automatique completude
  only_opus.each do |qnum|
    scores["opus"]["completude"] += 1
    judge_results << { question_number: qnum, note: "Presente uniquement dans Opus", "completude_winner" => "opus" }
  end
  only_mistral.each do |qnum|
    scores["mistral"]["completude"] += 1
    judge_results << { question_number: qnum, note: "Presente uniquement dans Mistral", "completude_winner" => "mistral" }
  end

  # --- Sauvegarde ---
  report = {
    subject_id:       subject_id,
    mode:             "pairwise",
    judge_model:      JUDGE_MODEL,
    generated_at:     Time.now.iso8601,
    questions_judged: common_numbers.size,
    only_in_opus:     only_opus,
    only_in_mistral:  only_mistral,
    total_cost_usd:   format("%.4f", total_cost),
    total_tokens:     { in: total_tokens_in, out: total_tokens_out },
    scores:           scores,
    details:          judge_results
  }
  report_path = subject_dir.join("pairwise_report.json")
  File.write(report_path, JSON.pretty_generate(report))

  summary_path = subject_dir.join("pairwise_summary.md")
  File.open(summary_path, "w") do |f|
    f.puts "# Jugement pairwise — Sujet ##{subject_id}"
    f.puts ""
    f.puts "Juge : `#{JUDGE_MODEL}` | #{common_numbers.size} questions | Cout : $#{format("%.4f", total_cost)}"
    f.puts ""
    f.puts "## Scores"
    f.puts ""
    f.puts "| Critere | Opus | Mistral | Egalite |"
    f.puts "|---------|------|---------|---------|"
    CRITERIA.each do |c|
      next if (scores["opus"][c] + scores["mistral"][c] + scores["egalite"][c]).zero?
      f.puts "| #{c} | #{scores["opus"][c]} | #{scores["mistral"][c]} | #{scores["egalite"][c]} |"
    end
    f.puts ""
    f.puts "## Vainqueur par critere"
    f.puts ""
    CRITERIA.each do |c|
      o, m = scores["opus"][c], scores["mistral"][c]
      winner = o > m ? "**Opus**" : m > o ? "**Mistral**" : "Egalite"
      f.puts "- #{c} : #{winner} (#{o} vs #{m})"
    end
    f.puts ""
    total_o = CRITERIA.sum { |c| scores["opus"][c] }
    total_m = CRITERIA.sum { |c| scores["mistral"][c] }
    f.puts "## Vainqueur global"
    f.puts ""
    f.puts total_o > total_m ? "**Opus** #{total_o} vs #{total_m}" :
           total_m > total_o ? "**Mistral** #{total_m} vs #{total_o}" :
           "Egalite #{total_o} vs #{total_m}"
    f.puts ""
    f.puts "## Detail par question"
    f.puts ""
    judge_results.each do |r|
      f.puts "### Q#{r[:question_number]}"
      if r[:error]
        f.puts "ERREUR : #{r[:error]}"
      elsif r[:note]
        f.puts "_#{r[:note]}_"
      else
        CRITERIA.each do |c|
          f.puts "- **#{c}** → #{r["#{c}_winner"]} : #{r["#{c}_reason"]}"
        end
      end
      f.puts ""
    end
  end

  # Resume terminal
  puts "\n#{"=" * 60}"
  puts "PAIRWISE — RESUME"
  puts "=" * 60
  puts "| Critere      | Opus | Mistral | Egalite |"
  puts "|--------------|------|---------|---------|"
  CRITERIA.each do |c|
    puts "| #{c.ljust(12)} | #{scores["opus"][c].to_s.center(4)} | #{scores["mistral"][c].to_s.center(7)} | #{scores["egalite"][c].to_s.center(7)} |"
  end
  total_o = CRITERIA.sum { |c| scores["opus"][c] }
  total_m = CRITERIA.sum { |c| scores["mistral"][c] }
  puts "\nTOTAL : Opus #{total_o} | Mistral #{total_m}"
  puts "Cout  : $#{format("%.4f", total_cost)} (#{total_tokens_in} in / #{total_tokens_out} out)"
  puts "\nRapport JSON : #{report_path}"
  puts "Rapport MD   : #{summary_path}"
end
