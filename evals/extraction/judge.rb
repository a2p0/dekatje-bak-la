# Dispatcher — lance le juge d'extraction selon le mode choisi.
#
# Usage:
#   bin/rails runner evals/extraction/judge.rb <subject_id> [--mode pairwise|absolute] [--models A,B]
#
# Modes :
#   pairwise (defaut) — compare deux modeles question par question (A/B/egalite)
#   absolute          — note chaque modele independamment (1-5 par critere)
#
# --models A,B : noms des fichiers JSON a comparer (sans extension)
#   Defaut : opus,mistral
#   Exemple : --models opus,mistral_ocr_opus
#
# Required env vars:
#   OPENROUTER_API_KEY  — GPT-5.5 via OpenRouter
#
# Output : tmp/llm_comparison/extraction/results/<subject_id>/
#   pairwise : pairwise_<A>_vs_<B>_report.json + pairwise_<A>_vs_<B>_summary.md
#   absolute : absolute_<A>_report.json + absolute_<B>_report.json + absolute_summary.md

$stdout.sync = true

subject_id = ARGV[0].to_i
mode_flag  = ARGV.include?("--mode")   ? ARGV[ARGV.index("--mode") + 1]   : "pairwise"
models_arg = ARGV.include?("--models") ? ARGV[ARGV.index("--models") + 1] : "opus,mistral"

model_a, model_b = models_arg.split(",").map(&:strip)

if subject_id.zero? || !%w[pairwise absolute].include?(mode_flag) || model_a.nil? || model_b.nil?
  puts "Usage: bin/rails runner evals/extraction/judge.rb <subject_id> [--mode pairwise|absolute] [--models A,B]"
  puts "  --models : noms des fichiers JSON (sans .json), ex: opus,mistral_ocr_opus"
  exit 1
end

openrouter_key = ENV["OPENROUTER_API_KEY"].presence || abort("OPENROUTER_API_KEY manquant")

OUTPUT_DIR  = Rails.root.join("tmp/llm_comparison/extraction/results")
subject_dir = OUTPUT_DIR.join(subject_id.to_s)

abort "Dossier introuvable : #{subject_dir}\nLance d'abord evals/extraction/run_comparison.rb." unless subject_dir.exist?

puts "Sujet ##{subject_id} — mode : #{mode_flag} — #{model_a} vs #{model_b}"
puts ""

judges_dir = Rails.root.join("evals/extraction/judges")

case mode_flag
when "pairwise"
  require judges_dir.join("pairwise_judge").to_s
  run_pairwise(subject_id, subject_dir, openrouter_key, model_a: model_a, model_b: model_b)
when "absolute"
  require judges_dir.join("absolute_judge").to_s
  run_absolute(subject_id, subject_dir, openrouter_key, model_a: model_a, model_b: model_b)
end
