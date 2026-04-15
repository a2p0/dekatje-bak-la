namespace :tutor do
  desc <<~DESC
    Simulate a full student-tutor conversation through the real
    Tutor::ProcessMessage pipeline and evaluate quality.

    Usage:
      rake tutor:simulate[SUBJECT_ID]

    Required env:
      OPENROUTER_API_KEY  Single OpenRouter key used for tutor, student and judge.

    Optional env:
      TURNS               Max conversation turns per question (default: 5)
      PROFILES            Comma-separated profiles (default: all)
                          Available: bon_eleve, eleve_moyen, eleve_en_difficulte,
                                     eleve_paresseux, eleve_hors_sujet
      QUESTIONS           Comma-separated question numbers to limit the run
                          (e.g. "1.1,1.2"). Default: all questions of the subject.
      TUTOR_MODEL         OpenRouter model id for the tutor
                          (default: openai/gpt-4o-mini)
      STUDENT_MODEL       OpenRouter model id for the simulated student
                          (default: openai/gpt-4o-mini)
      JUDGE_MODEL         OpenRouter model id for the judge
                          (default: anthropic/claude-sonnet-4)

    Examples:
      rake tutor:simulate[42]
      rake tutor:simulate[1] TURNS=2 PROFILES=bon_eleve QUESTIONS=1.1
      rake tutor:simulate[42] TUTOR_MODEL=mistralai/mistral-large-2512
  DESC
  task :simulate, [ :subject_id ] => :environment do |_t, args|
    subject_id = args[:subject_id] || ENV["SUBJECT_ID"]
    abort "Usage: rake tutor:simulate[SUBJECT_ID]" unless subject_id

    api_key = ENV["OPENROUTER_API_KEY"]
    abort "Set OPENROUTER_API_KEY in env" if api_key.blank?

    subject = Subject.find_by(id: subject_id)
    abort "Subject ##{subject_id} not found" unless subject

    questions_count = subject.parts.flat_map { |p| p.questions.kept }.size
    abort "Subject ##{subject_id} has no questions" if questions_count.zero?

    max_turns     = (ENV["TURNS"] || 5).to_i
    tutor_model   = ENV.fetch("TUTOR_MODEL",   "openai/gpt-4o-mini")
    student_model = ENV.fetch("STUDENT_MODEL", "openai/gpt-4o-mini")
    judge_model   = ENV.fetch("JUDGE_MODEL",   "anthropic/claude-sonnet-4")

    profiles = if ENV["PROFILES"]
      ENV["PROFILES"].split(",").map(&:strip)
    else
      TutorSimulation::StudentSimulator::PROFILES.keys.map(&:to_s)
    end

    question_numbers = ENV["QUESTIONS"]&.split(",")&.map(&:strip)

    student_client = AiClientFactory.build(provider: :openrouter, api_key: api_key, model: student_model)
    judge_client   = AiClientFactory.build(provider: :openrouter, api_key: api_key, model: judge_model)

    runner = TutorSimulation::Runner.new(
      subject:          subject,
      profiles:         profiles,
      max_turns:        max_turns,
      api_key:          api_key,
      tutor_model:      tutor_model,
      student_client:   student_client,
      judge_client:     judge_client,
      question_numbers: question_numbers
    )

    runner.run
  end
end
