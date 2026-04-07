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

    it "system prompt states parts are independent" do
      expect(result[:system]).to include("INDÉPENDANTE")
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

    # --- System prompt: verbatim rule ---

    it "system prompt requires verbatim extraction" do
      expect(result[:system]).to include("VERBATIM")
    end

    it "system prompt lists verbatim fields" do
      system = result[:system]
      %w[presentation label context correction].each do |field|
        expect(system).to include(field), "expected system prompt to mention verbatim field '#{field}'"
      end
    end

    it "system prompt forbids adding or removing words" do
      expect(result[:system]).to include("ajouté, retiré ou reformulé")
    end

    # --- System prompt: answer_type enum ---

    it "system prompt mentions answer_type enum values" do
      system = result[:system]

      %w[text calculation argumentation dr_reference completion choice].each do |type|
        expect(system).to include(type), "expected system prompt to include answer_type '#{type}'"
      end
    end

    # --- System prompt: data_hints sources ---

    it "system prompt mentions all data_hints source values" do
      system = result[:system]

      %w[mise_en_situation question_context question_precedente].each do |source|
        expect(system).to include(source), "expected system prompt to include data_hints source '#{source}'"
      end
    end

    it "system prompt requires numbered DT/DR references in data_hints" do
      system = result[:system]
      expect(system).to include("DT1")
      expect(system).to include("DTS1")
      expect(system).to include("DR1")
      expect(system).to include("DRS1")
    end

    it "system prompt forbids generic DT/DR labels" do
      expect(result[:system]).to include("jamais un label générique")
    end

    # --- System prompt: document naming conventions ---

    it "system prompt defines DTS/DRS convention for specific parts" do
      system = result[:system]
      expect(system).to include("DTS1")
      expect(system).to include("DRS1")
    end

    # --- System prompt: explanation rules ---

    it "system prompt requires citations in explanation" do
      expect(result[:system]).to include("citations exactes")
    end

    it "system prompt requires step-by-step reasoning in explanation" do
      expect(result[:system]).to include("raisonnement étape par étape")
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

    # --- System prompt: specific parts numbering ---

    it "system prompt specifies letter numbering for specific parts" do
      system = result[:system]
      expect(system).to include("A, B, C")
      expect(system).to include("A.1")
    end

    # --- System prompt: few-shot example ---

    it "system prompt includes a few-shot example" do
      system = result[:system]
      expect(system).to include("Exemple d'extraction attendue")
    end

    it "few-shot example shows common part with numbered DT" do
      expect(result[:system]).to include('"DT2"')
    end

    it "few-shot example shows specific part with DTS/DRS" do
      system = result[:system]
      expect(system).to include('"DTS1"')
      expect(system).to include('"DRS1"')
    end

    it "few-shot example shows question_context as data_hint source" do
      expect(result[:system]).to include('"question_context"')
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

    # --- skip_common mode ---

    context "when skip_common is true" do
      subject(:result) do
        described_class.call(
          subject_text: subject_text,
          correction_text: correction_text,
          specialty: specialty,
          skip_common: true
        )
      end

      it "system prompt includes skip common addendum" do
        expect(result[:system]).to include("La partie commune a déjà été extraite")
      end

      it "system prompt instructs to return empty common_parts" do
        expect(result[:system]).to include("Ne retourne PAS de common_parts")
      end

      it "user message instructs to extract only specific parts" do
        user_contents = result[:messages].map { |m| m[:content] }.join(" ")
        expect(user_contents).to include("uniquement les parties spécifiques")
      end

      it "user message instructs to ignore common part" do
        user_contents = result[:messages].map { |m| m[:content] }.join(" ")
        expect(user_contents).to include("Ignore la partie commune")
      end
    end

    context "when skip_common is false (default)" do
      it "system prompt does NOT include skip common addendum" do
        expect(result[:system]).not_to include("La partie commune a déjà été extraite")
      end

      it "user message instructs to extract all parts" do
        user_contents = result[:messages].map { |m| m[:content] }.join(" ")
        expect(user_contents).to include("toutes les parties communes et spécifiques")
      end
    end
  end
end
