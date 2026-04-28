namespace :subjects do
  desc "Soft-delete subjects stuck in :uploading status older than 24 hours"
  task cleanup_uploading: :environment do
    cutoff  = 24.hours.ago
    stale   = Subject.where(status: :uploading).where("created_at < ?", cutoff)
    count   = stale.count
    stale.update_all(discarded_at: Time.current)
    puts "Archived #{count} stale uploading subject(s) (created before #{cutoff})."
  end

  desc "Enrich structured_correction for all subjects (or a specific subject_id)"
  task :enrich_structured_correction, [ :subject_id ] => :environment do |_, args|
    subjects = if args[:subject_id].present?
      [ Subject.find(args[:subject_id]) ]
    else
      Subject.joins(parts: { questions: :answer })
             .where(answers: { structured_correction: nil })
             .distinct
    end

    total_enriched = 0
    total_skipped  = 0
    total_errors   = 0

    subjects.each do |subject|
      puts "Subject: #{subject.title} (ID: #{subject.id})"

      resolved = ResolveApiKey.call(user: subject.owner)
      result   = EnrichAllAnswers.call(
        subject:  subject,
        api_key:  resolved.api_key,
        provider: resolved.provider
      )

      puts "  Résumé: #{result[:enriched]} enrichie(s), #{result[:skipped]} skippée(s), #{result[:errors]} erreur(s)"

      total_enriched += result[:enriched]
      total_skipped  += result[:skipped]
      total_errors   += result[:errors]
    end

    puts ""
    puts "Total: #{subjects.size} subject(s), #{total_enriched} enrichie(s), #{total_skipped} skippée(s), #{total_errors} erreur(s)"
  end
end
