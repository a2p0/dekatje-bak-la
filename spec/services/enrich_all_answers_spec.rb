require "rails_helper"

RSpec.describe EnrichAllAnswers do
  let(:subject_obj) { create(:subject, :new_format) }
  let(:api_key) { "sk-test" }
  let(:provider) { :anthropic }

  let(:success_result) do
    EnrichStructuredCorrection::Result.new(
      ok: true,
      structured_correction: { "input_data" => [], "final_answers" => [], "intermediate_steps" => [], "common_errors" => [] },
      error: nil
    )
  end

  let(:failure_result) do
    EnrichStructuredCorrection::Result.new(ok: false, structured_correction: nil, error: "API timeout")
  end

  def build_answer_for_subject(subj)
    part     = create(:part, subject: subj)
    question = create(:question, part: part)
    create(:answer, question: question)
  end

  describe ".call" do
    context "with 3 answers, 1 API error" do
      let!(:answer1) { build_answer_for_subject(subject_obj) }
      let!(:answer2) { build_answer_for_subject(subject_obj) }
      let!(:answer3) { build_answer_for_subject(subject_obj) }

      before do
        allow(EnrichStructuredCorrection).to receive(:call).and_return(
          success_result,
          failure_result,
          success_result
        )
      end

      it "returns enriched: 2 and errors: 1" do
        result = described_class.call(subject: subject_obj.reload, api_key: api_key, provider: provider)
        expect(result[:enriched]).to eq(2)
        expect(result[:errors]).to eq(1)
      end

      it "does not raise an exception" do
        expect {
          described_class.call(subject: subject_obj.reload, api_key: api_key, provider: provider)
        }.not_to raise_error
      end

      it "persists structured_correction for successful answers" do
        described_class.call(subject: subject_obj.reload, api_key: api_key, provider: provider)
        expect(answer1.reload.structured_correction).to be_present
        expect(answer3.reload.structured_correction).to be_present
      end

      it "leaves structured_correction nil for failed answers" do
        described_class.call(subject: subject_obj.reload, api_key: api_key, provider: provider)
        expect(answer2.reload.structured_correction).to be_nil
      end
    end

    context "when all 3 answers succeed" do
      let!(:answer1) { build_answer_for_subject(subject_obj) }
      let!(:answer2) { build_answer_for_subject(subject_obj) }
      let!(:answer3) { build_answer_for_subject(subject_obj) }

      before do
        allow(EnrichStructuredCorrection).to receive(:call).and_return(success_result)
      end

      it "returns enriched: 3 and errors: 0" do
        result = described_class.call(subject: subject_obj.reload, api_key: api_key, provider: provider)
        expect(result[:enriched]).to eq(3)
        expect(result[:errors]).to eq(0)
      end
    end

    context "when an answer is already enriched" do
      let!(:unenriched_answer)  { build_answer_for_subject(subject_obj) }
      let!(:enriched_answer) do
        ans = build_answer_for_subject(subject_obj)
        ans.update!(structured_correction: { "input_data" => [], "final_answers" => [], "intermediate_steps" => [], "common_errors" => [] })
        ans
      end

      before do
        allow(EnrichStructuredCorrection).to receive(:call).and_return(success_result)
      end

      it "skips answers already enriched" do
        result = described_class.call(subject: subject_obj.reload, api_key: api_key, provider: provider)
        expect(result[:skipped]).to eq(1)
        expect(result[:enriched]).to eq(1)
      end

      it "calls EnrichStructuredCorrection only for the unenriched answer" do
        described_class.call(subject: subject_obj.reload, api_key: api_key, provider: provider)
        expect(EnrichStructuredCorrection).to have_received(:call).once
      end
    end
  end
end
