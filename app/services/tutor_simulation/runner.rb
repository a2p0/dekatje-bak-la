module TutorSimulation
  class Runner
    SIM_TEACHER_EMAIL  = "tutor-sim@dekatje.local".freeze
    SIM_CLASSROOM_NAME = "tutor-sim".freeze

    def initialize(
      subject:,
      profiles:,
      max_turns:,
      api_key:,
      tutor_model:,
      student_client:,
      judge_client:,
      output_dir: nil,
      question_numbers: nil
    )
      @subject          = subject
      @profiles         = profiles.map(&:to_sym)
      @max_turns        = max_turns
      @api_key          = api_key
      @tutor_model      = tutor_model
      @student_client   = student_client
      @judge_client     = judge_client
      @question_numbers = question_numbers&.map(&:to_s)
      @output_dir       = output_dir || Rails.root.join("tmp", "tutor_simulations", Time.current.strftime("%Y%m%d_%H%M%S"))
    end

    def run
      FileUtils.mkdir_p(@output_dir)

      sim_classroom = ensure_sim_classroom
      questions     = @subject.parts.order(:position).flat_map { |p| p.questions.kept.order(:position) }
      questions     = questions.select { |q| @question_numbers.include?(q.number.to_s) } if @question_numbers&.any?
      abort "No questions match QUESTIONS=#{@question_numbers.inspect}" if questions.empty?

      puts "=== Simulation tuteur : #{@subject.title} ==="
      puts "    #{questions.size} questions, #{@profiles.size} profils, #{@max_turns} tours max"
      puts "    Output: #{@output_dir}"
      puts ""

      results = questions.map.with_index do |question, qi|
        puts "--- Question #{question.number} (#{qi + 1}/#{questions.size}) ---"
        simulate_question(question, sim_classroom)
      end

      simulation_data = build_simulation_data(results)
      write_reports(simulation_data)
      simulation_data
    end

    private

    def ensure_sim_classroom
      teacher = User.find_or_create_by!(email: SIM_TEACHER_EMAIL) do |u|
        u.password           = SecureRandom.hex(16)
        u.first_name         = "Tutor"
        u.last_name          = "Simulator"
        u.confirmed_at       = Time.current
      end

      teacher.update!(openrouter_api_key: @api_key) if teacher.openrouter_api_key != @api_key

      classroom = teacher.classrooms.find_or_create_by!(name: SIM_CLASSROOM_NAME) do |c|
        c.school_year             = "sim"
        c.specialty               = "tronc_commun"
        c.access_code             = "tutor-sim"
        c.tutor_free_mode_enabled = true
      end

      ClassroomSubject.find_or_create_by!(classroom: classroom, subject: @subject)

      classroom
    end

    def simulate_question(question, classroom)
      profile_results = @profiles.map do |profile|
        puts "  Profil: #{profile}"
        simulate_profile(question, profile, classroom)
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

    def simulate_profile(question, profile, classroom)
      simulator = StudentSimulator.new(profile: profile, client: @student_client)
      sim_student = build_sim_student(profile, classroom)
      conversation = build_conversation(sim_student)

      configure_ruby_llm

      transcript = []

      @max_turns.times do |turn|
        student_message = simulator.respond(
          question_label:       question.label,
          conversation_history: transcript,
          turn:                 turn + 1
        )
        transcript << { "role" => "user", "content" => student_message }
        print "    [#{turn + 1}/#{@max_turns}] élève ✓ "

        result = Tutor::ProcessMessage.call(
          conversation:  conversation,
          student_input: student_message,
          question:      question
        )

        if result.err?
          puts "tuteur ✗ (#{result.error})"
          transcript << { "role" => "assistant", "content" => "[ERREUR : #{result.error}]" }
          break
        end

        last_assistant = conversation.messages.where(role: :assistant).order(:created_at).last
        transcript << { "role" => "assistant", "content" => last_assistant&.content.to_s }
        puts "tuteur ✓"
      end

      conversation.reload

      structural = StructuralMetrics.compute(conversation: conversation)

      puts "    Évaluation..."
      evaluation = judge_transcript(question, profile, simulator.profile_label, transcript)

      {
        profile:               profile.to_s,
        profile_label:         simulator.profile_label,
        student_id:            sim_student.id,
        conversation_id:       conversation.id,
        transcript:            transcript,
        structural_metrics:    structural,
        evaluation:            evaluation,
        final_phase:           conversation.tutor_state.current_phase,
        final_lifecycle_state: conversation.lifecycle_state
      }
    end

    def build_sim_student(profile, classroom)
      username = "sim-#{profile}-#{SecureRandom.hex(4)}"
      classroom.students.create!(
        first_name:       "Sim",
        last_name:        profile.to_s,
        username:         username,
        password:         "password123",
        api_key:          nil,             # uses classroom free mode (teacher key)
        api_provider:     :openrouter,
        api_model:        @tutor_model,    # picked up by ResolveTutorApiKey in free-mode
        use_personal_key: false
      )
    end

    def build_conversation(student)
      Conversation.create!(
        student:         student,
        subject:         @subject,
        lifecycle_state: "active",
        tutor_state:     TutorState.default
      )
    end

    def configure_ruby_llm
      RubyLLM.configure do |config|
        config.openrouter_api_key = @api_key
      end
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
        tutor_provider:   "openrouter (real pipeline)",
        tutor_model:      @tutor_model,
        student_provider: @student_client.instance_variable_get(:@provider).to_s,
        student_model:    @student_client.instance_variable_get(:@model).to_s,
        judge_provider:   @judge_client.instance_variable_get(:@provider).to_s,
        judge_model:      @judge_client.instance_variable_get(:@model).to_s,
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
