# Usage: bin/rails runner tmp/extraction_comparison/persist_winner.rb <subject_id> <opus|mistral>
#
# Charge le JSON brut du modele gagnant et l'enregistre dans extraction_jobs.raw_json
# pour inspection. NE persiste PAS les questions/parts en DB.
#
# Pour persister les donnees extraites, appele PersistExtractedData manuellement
# apres avoir verifie le JSON.

$stdout.sync = true

subject_id   = ARGV[0].to_i
model_key    = ARGV[1].to_s.downcase

if subject_id.zero? || model_key.empty? || !%w[opus mistral].include?(model_key)
  puts "Usage: bin/rails runner tmp/extraction_comparison/persist_winner.rb <subject_id> <opus|mistral>"
  exit 1
end

json_path = Rails.root.join("tmp/extraction_comparison/results/#{subject_id}/#{model_key}.json")
unless File.exist?(json_path)
  abort "Fichier introuvable : #{json_path}\nLance d'abord run_comparison.rb."
end

subject = Subject.find_by(id: subject_id)
abort "Sujet ##{subject_id} introuvable." unless subject

raw_json = File.read(json_path)

puts "Sujet ##{subject_id} — modele gagnant : #{model_key}"
puts "Fichier JSON : #{json_path} (#{raw_json.length} cars)"

# Verification JSON valide
begin
  # Nettoie les fences markdown eventuelles
  clean = raw_json.strip.gsub(/\A```(?:json)?\n?/, "").gsub(/\n?```\z/, "")
  parsed = JSON.parse(clean)
  puts "JSON valide : #{parsed.keys.join(", ")}"
rescue JSON::ParseError => e
  abort "JSON invalide : #{e.message}\nVerifie le fichier manuellement avant de persister."
end

# Sauvegarde dans extraction_jobs.raw_json pour reference
job = subject.extraction_job
if job
  job.update!(raw_json: raw_json, status: :done)
  puts "ExtractionJob ##{job.id} mis a jour : status=done, raw_json sauvegarde."
else
  puts "Aucun ExtractionJob trouve pour ce sujet — creation..."
  job = subject.create_extraction_job!(status: :done, raw_json: raw_json, provider_used: :server)
  puts "ExtractionJob ##{job.id} cree."
end

puts "\nJSON sauvegarde dans extraction_jobs.raw_json."
puts "Tu peux maintenant appeler PersistExtractedData depuis la console pour persister les donnees :"
puts ""
puts "  subject = Subject.find(#{subject_id})"
puts "  raw = subject.extraction_job.raw_json"
puts "  data = MapExtractedMetadata.call(raw)  # pour verifier les metadonnees"
puts "  # Puis pour persister les questions/parts :"
puts "  PersistExtractedData.call(subject: subject, data: JSON.parse(raw.gsub(/\\A```(?:json)?\\n?/, '').gsub(/\\n?```\\z/, '')))"
