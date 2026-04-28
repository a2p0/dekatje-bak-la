# Dispatcher — lance le juge d'extraction selon le mode choisi.
#
# Usage:
#   bin/rails runner evals/extraction/judge.rb <subject_id> [--mode pairwise|absolute]
#
# Modes :
#   pairwise (defaut) — compare Opus vs Mistral question par question (A/B/egalite)
#   absolute          — note chaque modele independamment (1-5 par critere)
#
# Required env vars:
#   OPENROUTER_API_KEY  — GPT-5.5 via OpenRouter
#
# Output : tmp/llm_comparison/extraction/results/<subject_id>/
#   pairwise : pairwise_report.json + pairwise_summary.md
#   absolute : absolute_report.json + absolute_summary.md

$stdout.sync = true

subject_id = ARGV[0].to_i
mode_flag  = ARGV.include?("--mode") ? ARGV[ARGV.index("--mode") + 1] : "pairwise"

if subject_id.zero? || !%w[pairwise absolute].include?(mode_flag)
  puts "Usage: bin/rails runner evals/extraction/judge.rb <subject_id> [--mode pairwise|absolute]"
  exit 1
end

openrouter_key = ENV["OPENROUTER_API_KEY"].presence || abort("OPENROUTER_API_KEY manquant")

OUTPUT_DIR  = Rails.root.join("tmp/llm_comparison/extraction/results")
subject_dir = OUTPUT_DIR.join(subject_id.to_s)

abort "Dossier introuvable : #{subject_dir}\nLance d'abord evals/extraction/run_comparison.rb." unless subject_dir.exist?

puts "Sujet ##{subject_id} — mode : #{mode_flag}"
puts ""

judges_dir = Rails.root.join("evals/extraction/judges")

case mode_flag
when "pairwise"
  require judges_dir.join("pairwise_judge").to_s
  run_pairwise(subject_id, subject_dir, openrouter_key)
when "absolute"
  require judges_dir.join("absolute_judge").to_s
  run_absolute(subject_id, subject_dir, openrouter_key)
end
