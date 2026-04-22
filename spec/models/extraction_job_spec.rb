require "rails_helper"

RSpec.describe ExtractionJob, type: :model do
  describe "enums" do
    it "defines status enum with pending as default" do
      job = build(:extraction_job)
      expect(job.status).to eq("pending")
    end

    it "defines all status values" do
      expect(ExtractionJob.statuses).to eq(
        "pending" => 0, "processing" => 1, "done" => 2, "failed" => 3
      )
    end

    it "defines provider_used enum" do
      expect(ExtractionJob.provider_useds).to eq("teacher" => 0, "server" => 1)
    end
  end

  describe "associations" do
    it "belongs to subject" do
      job = build(:extraction_job)
      expect(job.subject).to be_a(Subject)
    end
  end
end