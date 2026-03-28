require "rails_helper"

RSpec.describe BuildExtractionPrompt do
  describe ".call" do
    let(:text) { "Partie 1 - Question 1.1 : Calculer la consommation." }

    subject(:result) { described_class.call(text: text) }

    it "returns a hash with system and messages keys" do
      expect(result).to have_key(:system)
      expect(result).to have_key(:messages)
    end

    it "system prompt contains JSON schema instructions" do
      expect(result[:system]).to include("JSON")
      expect(result[:system]).to include("parts")
      expect(result[:system]).to include("questions")
    end

    it "messages contain the PDF text" do
      expect(result[:messages].first[:content]).to include(text)
    end

    it "messages use user role" do
      expect(result[:messages].first[:role]).to eq("user")
    end

    it "instructs to extract data_hints" do
      expect(result[:system]).to include("data_hints")
    end
  end
end
