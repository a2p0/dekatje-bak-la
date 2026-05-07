require "rails_helper"

# 062 invariant: no hard dependency on Anthropic in the main tutor path.
# Classifier uses the server-side ANTHROPIC_API_KEY by design — that's
# decoupled from the student's provider.
RSpec.describe "Tutor cross-provider integration", type: :service do
  let(:student) { create(:student) }
  let(:subject_record) { create(:subject) }
  let(:question) { create(:question, part: create(:part, subject: subject_record), answer_type: "calcul") }
  let!(:answer) { create(:answer, question: question) }
  let(:conversation) do
    create(:conversation, student: student, subject: subject_record, lifecycle_state: "active")
  end

  shared_examples "tutor pipeline runs end-to-end" do |provider|
    it "executes ProcessMessage with provider=#{provider}" do
      stub_const("ENV", ENV.to_hash.merge("ANTHROPIC_API_KEY" => "test-key"))
      student.update!(api_provider: provider, api_key: "fake-key")

      allow(Tutor::CallLlm).to receive(:call).and_return(
        Tutor::Result.ok(full_content: "Tutor response.")
      )
      allow(Tutor::Classify).to receive(:call).and_return(
        Tutor::Result.ok(annotation: { "gives_formula" => false, "concepts" => [] })
      )
      allow(Tutor::BroadcastDone).to receive(:call).and_return(Tutor::Result.ok)

      result = Tutor::ProcessMessage.call(
        conversation:  conversation,
        student_input: "Bonjour",
        question:      question,
        access_code:   "tutor-sim"
      )

      expect(result.ok?).to be(true)
    end
  end

  it_behaves_like "tutor pipeline runs end-to-end", "anthropic"
  it_behaves_like "tutor pipeline runs end-to-end", "openrouter"
  it_behaves_like "tutor pipeline runs end-to-end", "openai"
  it_behaves_like "tutor pipeline runs end-to-end", "google"
end
