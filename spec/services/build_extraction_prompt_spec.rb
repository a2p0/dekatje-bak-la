require "rails_helper"

RSpec.describe BuildExtractionPrompt do
  describe ".call" do
    let(:subject_text) { "--- Page 1 ---\nPartie 1 - Question 1.1 : Calculer la consommation.\nPartie 2 - Question 2.1 : Justifier le choix." }
    let(:correction_text) { "--- Page 1 ---\nQuestion 1.1 : 56,73 litres\nQuestion 2.1 : Le choix est justifié par..." }
    let(:specialty) { "ITEC" }

    subject(:result) do
      described_class.call(
        subject_text: subject_text,
        correction_text: correction_text,
        specialty: specialty
      )
    end

    it "returns a hash with :system and :messages keys" do
      expect(result).to have_key(:system)
      expect(result).to have_key(:messages)
    end

    # --- System prompt: common/specific distinction ---

    it "system prompt mentions common and specific parts distinction" do
      expect(result[:system]).to include("common")
      expect(result[:system]).to include("specific")
    end

    it "system prompt mentions common parts worth 12 points" do
      expect(result[:system]).to include("12")
    end

    it "system prompt mentions specific parts worth 8 points" do
      expect(result[:system]).to include("8")
    end

    # --- System prompt: JSON schema keys ---

    it "system prompt defines common_parts key in the JSON schema" do
      expect(result[:system]).to include("common_parts")
    end

    it "system prompt defines specific_parts key in the JSON schema" do
      expect(result[:system]).to include("specific_parts")
    end

    it "system prompt defines document_references key in the JSON schema" do
      expect(result[:system]).to include("document_references")
    end

    it "system prompt defines metadata key in the JSON schema" do
      expect(result[:system]).to include("metadata")
    end

    it "system prompt defines presentation key in the JSON schema" do
      expect(result[:system]).to include("presentation")
    end

    # --- System prompt: answer_type enum ---

    it "system prompt mentions answer_type enum values" do
      system = result[:system]

      %w[text calculation argumentation dr_reference completion choice].each do |type|
        expect(system).to include(type), "expected system prompt to include answer_type '#{type}'"
      end
    end

    # --- System prompt: data_hints sources ---

    it "system prompt mentions data_hints source values" do
      system = result[:system]

      expect(system).to include("data_hints")
      %w[DT DR].each do |source|
        expect(system).to include(source), "expected system prompt to include data_hints source '#{source}'"
      end
    end

    # --- System prompt: dt_references and dr_references ---

    it "system prompt mentions dt_references per question" do
      expect(result[:system]).to include("dt_references")
    end

    it "system prompt mentions dr_references per question" do
      expect(result[:system]).to include("dr_references")
    end

    # --- System prompt: cross-referencing with corrections ---

    it "system prompt instructs to cross-reference questions with corrections" do
      expect(result[:system]).to include("correction")
    end

    # --- System prompt: page numbers for DTs/DRs ---

    it "system prompt instructs to identify DTs and DRs with page numbers" do
      system = result[:system]

      expect(system).to include("DT")
      expect(system).to include("DR")
      expect(system).to include("page")
    end

    # --- Messages: content and structure ---

    it "messages include the subject text" do
      user_contents = result[:messages].map { |m| m[:content] }.join(" ")

      expect(user_contents).to include(subject_text)
    end

    it "messages include the correction text" do
      user_contents = result[:messages].map { |m| m[:content] }.join(" ")

      expect(user_contents).to include(correction_text)
    end

    it "messages include the specialty parameter" do
      user_contents = result[:messages].map { |m| m[:content] }.join(" ")

      expect(user_contents).to include("ITEC")
    end

    it "messages use user role" do
      result[:messages].each do |message|
        expect(message[:role]).to eq("user")
      end
    end

    # --- Edge case: different specialty ---

    context "with a different specialty" do
      let(:specialty) { "SIN" }

      it "messages include the given specialty" do
        user_contents = result[:messages].map { |m| m[:content] }.join(" ")

        expect(user_contents).to include("SIN")
      end
    end
  end
end
