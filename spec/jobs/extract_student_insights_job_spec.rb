# spec/jobs/extract_student_insights_job_spec.rb
require "rails_helper"

RSpec.describe ExtractStudentInsightsJob, type: :job do
  let(:student) { create(:student, api_provider: :anthropic, api_key: "sk-test") }
  let(:question) { create(:question) }
  let(:conversation) { create(:conversation, student: student, question: question) }

  describe "#perform" do
    it "calls ExtractStudentInsights service" do
      expect(ExtractStudentInsights).to receive(:call).with(conversation: conversation)

      described_class.perform_now(conversation.id)
    end

    it "does nothing for non-existent conversation" do
      expect(ExtractStudentInsights).not_to receive(:call)

      described_class.perform_now(999999)
    end

    it "logs errors without raising" do
      allow(ExtractStudentInsights).to receive(:call).and_raise(StandardError, "test error")

      expect(Rails.logger).to receive(:error).with(/ExtractStudentInsightsJob.*test error/)

      described_class.perform_now(conversation.id)
    end
  end
end
