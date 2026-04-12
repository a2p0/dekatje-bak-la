require "rails_helper"

RSpec.describe ExtractQuestionsJob, type: :job do
  let(:subject_obj) { create(:subject, :new_format) }
  let(:extraction_job) { create(:extraction_job, subject: subject_obj, status: :pending) }

  let(:resolved_key) { ResolveApiKey::Result.new(api_key: "sk-test", provider: :anthropic) }
  let(:raw_response) { '{"presentation":"Test","parts":[]}' }
  let(:extracted_data) { { "presentation" => "Test", "parts" => [] } }

  before do
    extraction_job
    allow(ResolveApiKey).to receive(:call).and_return(resolved_key)
    allow(ExtractQuestionsFromPdf).to receive(:call).and_return([ raw_response, extracted_data ])
    allow(PersistExtractedData).to receive(:call).and_return(subject_obj)
    allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to)
  end

  describe "#perform" do
    it "sets extraction_job status to processing then done" do
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
        provider: :anthropic,
        skip_common: false
      )
    end

    it "calls PersistExtractedData with subject and data" do
      described_class.perform_now(subject_obj.id)
      expect(PersistExtractedData).to have_received(:call).with(
        subject: subject_obj,
        data: extracted_data
      )
    end

    it "broadcasts Turbo Stream updates to subject channel" do
      described_class.perform_now(subject_obj.id)
      stream = "subject_#{subject_obj.id}"

      expect(Turbo::StreamsChannel).to have_received(:broadcast_replace_to).with(
        stream, hash_including(target: "extraction-status")
      )
      expect(Turbo::StreamsChannel).to have_received(:broadcast_replace_to).with(
        stream, hash_including(target: "parts-list")
      )
      expect(Turbo::StreamsChannel).to have_received(:broadcast_replace_to).with(
        stream, hash_including(target: "subject-stats")
      )
    end

    it "has an associated exam_session" do
      expect(subject_obj.exam_session).to be_present
    end

    context "when exam_session already has common parts" do
      before do
        subject_obj.exam_session.common_parts.create!(
          number: 1, title: "Partie commune existante",
          objective_text: "Objectif", section_type: :common,
          position: 0
        )
      end

      it "passes skip_common: true to ExtractQuestionsFromPdf" do
        described_class.perform_now(subject_obj.id)
        expect(ExtractQuestionsFromPdf).to have_received(:call).with(
          subject: subject_obj,
          api_key: "sk-test",
          provider: :anthropic,
          skip_common: true
        )
      end
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

      it "still broadcasts Turbo Stream updates" do
        described_class.perform_now(subject_obj.id)
        expect(Turbo::StreamsChannel).to have_received(:broadcast_replace_to).at_least(:once)
      end
    end
  end
end
