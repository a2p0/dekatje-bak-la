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
      PROFILES            Comma-separated profiles (default: autonome,collaboratif,passif)
                          Available: autonome, collaboratif, passif
                          NOTE: depuis 063, le default est 3 profils (×3 coût LLM).
                          Pour un smoke test rapide : PROFILES=collaboratif
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
      rake tutor:simulate[1] TURNS=2 PROFILES=collaboratif QUESTIONS=1.1
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

    profiles = if ENV["PROFILES"].present?
      ENV["PROFILES"].split(",").map(&:strip)
    else
      TutorSimulation::StudentSimulator::PROFILES.keys.map(&:to_s)
    end

    question_numbers = ENV["QUESTIONS"].presence&.split(",")&.map(&:strip)

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

    data = runner.run

    puts "\n=== Métriques structurelles par conversation ==="
    data[:results].each do |result|
      result[:profiles].each do |pr|
        metrics = pr[:structural_metrics]
        next unless metrics

        puts "\nQ#{result[:question_number]} — profil #{pr[:profile]}:"
        puts "  resolution_rate:                   #{metrics[:resolution_rate]}"
        puts "  cap_violations:                    #{metrics[:cap_violations]}"
        puts "  mean_help_steps_before_resolution: #{metrics[:mean_help_steps_before_resolution]}"
        puts "  proactive_help_rate:               #{metrics[:proactive_help_rate]}"
        puts "  correct_attempts_after_help_rate:  #{metrics[:correct_attempts_after_help_rate]}"
        puts "  attempts_per_question:             #{metrics[:attempts_per_question]}"
        puts "  correction_view_rate:              #{metrics[:correction_view_rate]}"
        puts "  mean_turns_to_resolution:          #{metrics[:mean_turns_to_resolution]}"
      end
    end
  end
end
