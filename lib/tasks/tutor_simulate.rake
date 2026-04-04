namespace :tutor do
  desc <<~DESC
    Simulate a full student-tutor interaction on a subject and evaluate quality.

    Usage:
      rake tutor:simulate[SUBJECT_ID]

    Environment variables:
      TURNS             Max conversation turns per question (default: 5)
      PROFILES          Comma-separated profiles (default: all)
                        Available: bon_eleve, eleve_moyen, eleve_en_difficulte, eleve_paresseux, eleve_hors_sujet
      TUTOR_PROVIDER    AI provider for the tutor (default: anthropic)
      TUTOR_MODEL       AI model for the tutor (default: provider default)
      TUTOR_KEY         API key for the tutor (default: ANTHROPIC_API_KEY)
      STUDENT_PROVIDER  AI provider for the simulated student (default: anthropic)
      STUDENT_MODEL     AI model for the simulated student (default: provider default)
      STUDENT_KEY       API key for the simulated student (default: ANTHROPIC_API_KEY)
      JUDGE_PROVIDER    AI provider for the judge (default: anthropic)
      JUDGE_MODEL       AI model for the judge (default: provider default)
      JUDGE_KEY         API key for the judge (default: ANTHROPIC_API_KEY)

    Examples:
      rake tutor:simulate[42]
      rake tutor:simulate[42] TURNS=3 PROFILES=bon_eleve,eleve_paresseux
      rake tutor:simulate[42] TUTOR_PROVIDER=openrouter TUTOR_MODEL=mistralai/mistral-large-2512
  DESC
  task :simulate, [ :subject_id ] => :environment do |_t, args|
    subject_id = args[:subject_id] || ENV["SUBJECT_ID"]
    abort "Usage: rake tutor:simulate[SUBJECT_ID]" unless subject_id

    subject = Subject.find_by(id: subject_id)
    abort "Subject ##{subject_id} not found" unless subject

    questions_count = subject.parts.flat_map { |p| p.questions.kept }.size
    abort "Subject ##{subject_id} has no questions" if questions_count.zero?

    max_turns = (ENV["TURNS"] || 5).to_i
    fallback_key = ENV["ANTHROPIC_API_KEY"]

    profiles = if ENV["PROFILES"]
      ENV["PROFILES"].split(",").map(&:strip)
    else
      TutorSimulation::StudentSimulator::PROFILES.keys.map(&:to_s)
    end

    tutor_client = AiClientFactory.build(
      provider: ENV.fetch("TUTOR_PROVIDER", "anthropic"),
      api_key:  ENV.fetch("TUTOR_KEY", fallback_key),
      model:    ENV["TUTOR_MODEL"]
    )

    student_client = AiClientFactory.build(
      provider: ENV.fetch("STUDENT_PROVIDER", "anthropic"),
      api_key:  ENV.fetch("STUDENT_KEY", fallback_key),
      model:    ENV["STUDENT_MODEL"]
    )

    judge_client = AiClientFactory.build(
      provider: ENV.fetch("JUDGE_PROVIDER", "anthropic"),
      api_key:  ENV.fetch("JUDGE_KEY", fallback_key),
      model:    ENV["JUDGE_MODEL"]
    )

    runner = TutorSimulation::Runner.new(
      subject:        subject,
      profiles:       profiles,
      max_turns:      max_turns,
      tutor_client:   tutor_client,
      student_client: student_client,
      judge_client:   judge_client
    )

    runner.run
  end
end
