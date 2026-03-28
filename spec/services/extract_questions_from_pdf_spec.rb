require "rails_helper"

RSpec.describe ExtractQuestionsFromPdf do
  let(:subject_obj) { create(:subject) }

  describe ".call" do
    before do
      fake_reader = instance_double(PDF::Reader)
      allow(fake_reader).to receive(:pages).and_return([
        instance_double(PDF::Reader::Page, text: "Partie 1 Question 1.1 Calculer")
      ])
      allow(PDF::Reader).to receive(:new).and_return(fake_reader)

      fake_client = instance_double(AiClientFactory)
      allow(AiClientFactory).to receive(:build).and_return(fake_client)
      allow(fake_client).to receive(:call).and_return('{"presentation":"test","parts":[]}')
    end

    it "returns a parsed hash" do
      result = described_class.call(
        subject: subject_obj,
        api_key: "sk-test",
        provider: :anthropic
      )
      expect(result).to be_a(Hash)
      expect(result).to have_key("presentation")
    end

    it "calls AiClientFactory with correct provider and api_key" do
      described_class.call(subject: subject_obj, api_key: "sk-test", provider: :anthropic)
      expect(AiClientFactory).to have_received(:build).with(provider: :anthropic, api_key: "sk-test")
    end

    it "raises on invalid JSON response" do
      fake_client = instance_double(AiClientFactory)
      allow(AiClientFactory).to receive(:build).and_return(fake_client)
      allow(fake_client).to receive(:call).and_return("not valid json")

      expect {
        described_class.call(subject: subject_obj, api_key: "sk-test", provider: :anthropic)
      }.to raise_error(ExtractQuestionsFromPdf::ParseError)
    end
  end
end
