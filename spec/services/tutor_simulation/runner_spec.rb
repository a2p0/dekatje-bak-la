require "rails_helper"

RSpec.describe TutorSimulation::Runner do
  let(:teacher)        { create(:user, openrouter_api_key: "or-test") }
  let(:exam_subject)   { create(:subject, owner: teacher, status: :published) }
  let(:part)           { create(:part, subject: exam_subject) }
  let!(:question)      { create(:question, part: part, label: "Calculer la consommation") }
  let!(:answer)        { create(:answer, question: question, correction_text: "56,73 l") }

  # Stub student & judge clients so we don't make network calls.
  let(:student_client) do
    instance_double(AiClientFactory, call: "Je ne sais pas trop, peux-tu m'aider ?")
  end
  let(:judge_client) do
    instance_double(
      AiClientFactory,
      call: {
        "non_divulgation"    => { "score" => 5, "justification" => "OK" },
        "guidage_progressif" => { "score" => 4, "justification" => "OK" },
        "bienveillance"      => { "score" => 5, "justification" => "OK" },
        "focalisation"       => { "score" => 4, "justification" => "OK" },
        "respect_process"    => { "score" => 3, "justification" => "OK" },
        "synthese"           => "OK"
      }.to_json
    )
  end

  before do
    FakeRubyLlm.setup_stub(content: "Bonjour ! Quelle est ta première intuition ?", tool_calls: [])
    allow(student_client).to receive(:instance_variable_get).with(:@provider).and_return(:openrouter)
    allow(student_client).to receive(:instance_variable_get).with(:@model).and_return("openai/gpt-4o-mini")
    allow(judge_client).to   receive(:instance_variable_get).with(:@provider).and_return(:openrouter)
    allow(judge_client).to   receive(:instance_variable_get).with(:@model).and_return("anthropic/claude-sonnet-4")
  end

  it "creates the sim classroom on first run" do
    runner = described_class.new(
      subject:        exam_subject,
      profiles:       [ "bon_eleve" ],
      max_turns:      1,
      api_key:        "or-test",
      tutor_model:    "openai/gpt-4o-mini",
      student_client: student_client,
      judge_client:   judge_client,
      output_dir:     Dir.mktmpdir
    )

    expect { runner.run }.to change(Classroom, :count).by(1).and change(Student, :count).by(1)
    expect(Classroom.find_by(name: "tutor-sim").tutor_free_mode_enabled).to be(true)
  end

  it "drives the real Tutor::ProcessMessage pipeline and persists messages" do
    runner = described_class.new(
      subject:        exam_subject,
      profiles:       [ "bon_eleve" ],
      max_turns:      1,
      api_key:        "or-test",
      tutor_model:    "openai/gpt-4o-mini",
      student_client: student_client,
      judge_client:   judge_client,
      output_dir:     Dir.mktmpdir
    )

    runner.run

    conv = Conversation.last
    expect(conv).to be_present
    expect(conv.messages.where(role: :user).count).to be >= 1
    expect(conv.messages.where(role: :assistant).count).to be >= 1
  end

  it "computes structural metrics and includes them in the report data" do
    output_dir = Dir.mktmpdir
    runner = described_class.new(
      subject:        exam_subject,
      profiles:       [ "bon_eleve" ],
      max_turns:      1,
      api_key:        "or-test",
      tutor_model:    "openai/gpt-4o-mini",
      student_client: student_client,
      judge_client:   judge_client,
      output_dir:     output_dir
    )

    data = runner.run
    profile_result = data[:results].first[:profiles].first

    expect(profile_result[:structural_metrics]).to be_a(Hash)
    expect(profile_result[:structural_metrics]).to include(:final_phase, :phase_rank, :open_question_ratio)
    expect(profile_result[:evaluation]["non_divulgation"]["score"]).to eq(5)
  end

  describe "SKIP_JUDGE guard" do
    let(:runner) do
      described_class.new(
        subject:        exam_subject,
        profiles:       [ "bon_eleve" ],
        max_turns:      1,
        api_key:        "or-test",
        tutor_model:    "openai/gpt-4o-mini",
        student_client: student_client,
        judge_client:   judge_client,
        output_dir:     Dir.mktmpdir
      )
    end

    context "when SKIP_JUDGE=1" do
      before { ENV["SKIP_JUDGE"] = "1" }
      after  { ENV.delete("SKIP_JUDGE") }

      it "does not call the judge client" do
        expect(judge_client).not_to receive(:call)
        runner.run
      end

      it "marks evaluation as skipped in each profile result" do
        data = runner.run
        profile_result = data[:results].first[:profiles].first
        expect(profile_result[:evaluation]).to eq("skipped" => true)
      end
    end

    context "when SKIP_JUDGE is absent" do
      it "calls the judge client normally (backward compat)" do
        runner.run
        expect(judge_client).to have_received(:call).at_least(:once)
      end
    end

    context "when SKIP_JUDGE=0" do
      before { ENV["SKIP_JUDGE"] = "0" }
      after  { ENV.delete("SKIP_JUDGE") }

      it "treats it as absent (strict == '1')" do
        runner.run
        expect(judge_client).to have_received(:call).at_least(:once)
      end
    end
  end
end