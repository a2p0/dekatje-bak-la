require "rails_helper"

RSpec.describe ExtractQuestionsJob, type: :job do
  let(:subject_obj) { create(:subject) }
  let(:extraction_job) { create(:extraction_job, subject: subject_obj, status: :pending) }

  let(:resolved_key) { { api_key: "sk-test", provider: :anthropic } }
  let(:extracted_data) { { "presentation" => "Test", "parts" => [] } }

  before do
    extraction_job
    allow(ResolveApiKey).to receive(:call).and_return(resolved_key)
    allow(ExtractQuestionsFromPdf).to receive(:call).and_return(extracted_data)
    allow(PersistExtractedData).to receive(:call).and_return(subject_obj)
    allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to)
  end

  describe "#perform" do
    it "sets extraction_job status to done after success" do
      described_class.perform_now(subject_obj.id)
      expect(extraction_job.reload.status).to eq("done")
    end

    it "calls ResolveApiKey with subject owner" do
      described_class.perform_now(subject_obj.id)
      expect(ResolveApiKey).to have_received(:call).with(user: subject_obj.owner)
    end

    it "calls ExtractQuestionsFromPdf with correct args" do
      described_class.perform_now(subject_obj.id)
      expect(ExtractQuestionsFromPdf).to have_received(:call).with(
        subject: subject_obj,
        api_key: "sk-test",
        provider: :anthropic
      )
    end

    it "calls PersistExtractedData" do
      described_class.perform_now(subject_obj.id)
      expect(PersistExtractedData).to have_received(:call).with(
        subject: subject_obj,
        data: extracted_data
      )
    end

    it "broadcasts Turbo Stream update" do
      described_class.perform_now(subject_obj.id)
      expect(Turbo::StreamsChannel).to have_received(:broadcast_replace_to)
    end

    context "when an error occurs" do
      before do
        allow(ExtractQuestionsFromPdf).to receive(:call).and_raise(StandardError, "API timeout")
      end

      it "sets extraction_job status to failed" do
        described_class.perform_now(subject_obj.id)
        expect(extraction_job.reload.status).to eq("failed")
      end

      it "stores the error message" do
        described_class.perform_now(subject_obj.id)
        expect(extraction_job.reload.error_message).to eq("API timeout")
      end
    end
  end
end
