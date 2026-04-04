module TutorSimulation
  class Runner
    def initialize(subject:, profiles:, max_turns:, tutor_client:, student_client:, judge_client:, output_dir: nil)
      @subject        = subject
      @profiles       = profiles.map(&:to_sym)
      @max_turns      = max_turns
      @tutor_client   = tutor_client
      @student_client = student_client
      @judge_client   = judge_client
      @output_dir     = output_dir || Rails.root.join("tmp", "tutor_simulations", Time.current.strftime("%Y%m%d_%H%M%S"))
    end

    def run
      FileUtils.mkdir_p(@output_dir)

      questions = @subject.parts.order(:position).flat_map { |p| p.questions.kept.order(:position) }

      puts "=== Simulation tuteur : #{@subject.title} ==="
      puts "    #{questions.size} questions, #{@profiles.size} profils, #{@max_turns} tours max"
      puts "    Output: #{@output_dir}"
      puts ""

      results = questions.map.with_index do |question, qi|
        puts "--- Question #{question.number} (#{qi + 1}/#{questions.size}) ---"
        simulate_question(question)
      end

      simulation_data = build_simulation_data(results)
      write_reports(simulation_data)
      simulation_data
    end

    private

    def simulate_question(question)
      profile_results = @profiles.map do |profile|
        puts "  Profil: #{profile}"
        simulate_profile(question, profile)
      end

      {
        question_id:     question.id,
        question_number: question.number,
        question_label:  question.label,
        points:          question.points,
        answer_type:     question.answer_type,
        correction:      question.answer&.correction_text,
        profiles:        profile_results
      }
    end

    def simulate_profile(question, profile)
      simulator = StudentSimulator.new(profile: profile, client: @student_client)
      transcript = []

      system_prompt = build_tutor_system_prompt(question)

      @max_turns.times do |turn|
        student_message = simulator.respond(
          question_label: question.label,
          conversation_history: transcript,
          turn: turn + 1
        )
        transcript << { "role" => "user", "content" => student_message }
        print "    [#{turn + 1}/#{@max_turns}] élève ✓ "

        tutor_messages = transcript.map { |m| { role: m["role"], content: m["content"] } }
        tutor_response = @tutor_client.call(
          messages: tutor_messages,
          system: system_prompt,
          max_tokens: 1024,
          temperature: 0.7
        )
        transcript << { "role" => "assistant", "content" => tutor_response }
        puts "tuteur ✓"
      end

      puts "    Évaluation..."
      evaluation = judge_transcript(question, profile, simulator.profile_label, transcript)

      {
        profile:       profile.to_s,
        profile_label: simulator.profile_label,
        transcript:    transcript,
        evaluation:    evaluation
      }
    end

    def build_tutor_system_prompt(question)
      part = question.part
      subject = part.subject

      BuildTutorPrompt::DEFAULT_TEMPLATE % {
        specialty:       subject.specialty,
        part_title:      part.title,
        objective_text:  part.objective_text.to_s,
        question_label:  question.label,
        context_text:    question.context_text.to_s,
        correction_text: question.answer&.correction_text.to_s
      }
    end

    def judge_transcript(question, profile, profile_label, transcript)
      judge = Judge.new(client: @judge_client)
      judge.evaluate(
        question_label:  question.label,
        student_profile: profile_label,
        correction_text: question.answer&.correction_text.to_s,
        transcript:      transcript
      )
    rescue => e
      puts "    ⚠ Erreur juge: #{e.message}"
      { "error" => e.message }
    end

    def build_simulation_data(results)
      {
        subject_id:       @subject.id,
        subject_title:    @subject.title,
        timestamp:        Time.current.iso8601,
        max_turns:        @max_turns,
        tutor_provider:   @tutor_client.instance_variable_get(:@provider),
        tutor_model:      @tutor_client.instance_variable_get(:@model),
        student_provider: @student_client.instance_variable_get(:@provider),
        student_model:    @student_client.instance_variable_get(:@model),
        judge_provider:   @judge_client.instance_variable_get(:@provider),
        judge_model:      @judge_client.instance_variable_get(:@model),
        results:          results
      }
    end

    def write_reports(simulation_data)
      generator = ReportGenerator.new(simulation_data)

      json_path = File.join(@output_dir, "raw.json")
      File.write(json_path, generator.to_json)
      puts "\n✓ JSON: #{json_path}"

      md_path = File.join(@output_dir, "report.md")
      File.write(md_path, generator.to_markdown)
      puts "✓ Markdown: #{md_path}"
    end
  end
end
