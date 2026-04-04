require "rails_helper"

RSpec.describe ExtractQuestionsFromPdf do
  let(:subject_obj) { create(:subject, :new_format) }

  let(:ai_response) do
    {
      "presentation" => "Le système CIME permet de transporter des charges lourdes.",
      "metadata" => { "exam_type" => "bac", "specialty" => "SIN", "year" => "2024" },
      "document_references" => [
        { "type" => "DT", "number" => 1, "title" => "Diagrammes SysML", "start_page" => 5, "end_page" => 7 },
        { "type" => "DR", "number" => 1, "title" => "Document réponse", "start_page" => 12, "end_page" => 13 }
      ],
      "common_parts" => [
        {
          "number" => 1,
          "title" => "Analyse fonctionnelle",
          "objective" => "Analyser le système CIME",
          "questions" => [
            {
              "number" => "1.1",
              "label" => "Identifier la fonction principale du CIME",
              "context" => "",
              "points" => 2,
              "answer_type" => "text",
              "dt_references" => [ "DT1" ],
              "dr_references" => [],
              "correction" => "Le CIME transporte des charges lourdes",
              "explanation" => "Il faut lire le diagramme des exigences",
              "data_hints" => [
                { "source" => "DT", "location" => "DT1, diagramme des exigences" }
              ],
              "key_concepts" => [ "analyse fonctionnelle", "exigences" ]
            }
          ]
        }
      ],
      "specific_parts" => [
        {
          "number" => 2,
          "title" => "Partie spécifique SIN",
          "objective" => "Programmer le microcontrôleur",
          "questions" => [
            {
              "number" => "2.1",
              "label" => "Écrire l'algorithme de commande",
              "context" => "Le microcontrôleur utilise un bus I2C",
              "points" => 4,
              "answer_type" => "text",
              "dt_references" => [ "DT1" ],
              "dr_references" => [ "DR1" ],
              "correction" => "Algorithme avec boucle while et lecture capteur",
              "explanation" => "L'algorithme doit lire les données du capteur via I2C",
              "data_hints" => [
                { "source" => "DT", "location" => "DT1, schéma du bus I2C" }
              ],
              "key_concepts" => [ "algorithme", "I2C" ]
            }
          ]
        }
      ]
    }.to_json
  end

  let(:subject_page1) { "Mise en situation du sujet CIME" }
  let(:subject_page2) { "Partie 1 - Question 1.1 Identifier la fonction principale" }
  let(:correction_page1) { "Correction Question 1.1 : Le CIME transporte des charges" }
  let(:correction_page2) { "Correction Question 2.1 : Algorithme avec boucle while" }

  let(:fake_client) { instance_double("AiClient") }

  before do
    # Mock PDF::Reader for subject_pdf
    subject_reader = instance_double(PDF::Reader)
    allow(subject_reader).to receive(:pages).and_return([
      instance_double(PDF::Reader::Page, text: subject_page1),
      instance_double(PDF::Reader::Page, text: subject_page2)
    ])

    # Mock PDF::Reader for correction_pdf
    correction_reader = instance_double(PDF::Reader)
    allow(correction_reader).to receive(:pages).and_return([
      instance_double(PDF::Reader::Page, text: correction_page1),
      instance_double(PDF::Reader::Page, text: correction_page2)
    ])

    # PDF::Reader.new returns the right reader based on call order
    allow(PDF::Reader).to receive(:new).and_return(subject_reader, correction_reader)

    # Mock AI client
    allow(AiClientFactory).to receive(:build).and_return(fake_client)
    allow(fake_client).to receive(:call).and_return(ai_response)
  end

  describe ".call" do
    it "accepts subject:, api_key:, and provider: params" do
      expect {
        described_class.call(subject: subject_obj, api_key: "sk-test", provider: :anthropic)
      }.not_to raise_error
    end

    it "reads text from subject.subject_pdf" do
      described_class.call(subject: subject_obj, api_key: "sk-test", provider: :anthropic)

      expect(PDF::Reader).to have_received(:new).at_least(:twice)
    end

    it "reads text from subject.correction_pdf" do
      described_class.call(subject: subject_obj, api_key: "sk-test", provider: :anthropic)

      # Both PDFs are read (subject_pdf and correction_pdf)
      expect(PDF::Reader).to have_received(:new).twice
    end

    it "includes page markers in extracted text" do
      allow(BuildExtractionPrompt).to receive(:call).and_call_original

      described_class.call(subject: subject_obj, api_key: "sk-test", provider: :anthropic)

      expect(BuildExtractionPrompt).to have_received(:call) do |args|
        expect(args[:subject_text]).to include("--- Page 1 ---")
        expect(args[:subject_text]).to include("--- Page 2 ---")
        expect(args[:subject_text]).to include(subject_page1)
        expect(args[:subject_text]).to include(subject_page2)

        expect(args[:correction_text]).to include("--- Page 1 ---")
        expect(args[:correction_text]).to include("--- Page 2 ---")
        expect(args[:correction_text]).to include(correction_page1)
        expect(args[:correction_text]).to include(correction_page2)
      end
    end

    it "calls BuildExtractionPrompt with subject_text, correction_text, and specialty" do
      allow(BuildExtractionPrompt).to receive(:call).and_call_original

      described_class.call(subject: subject_obj, api_key: "sk-test", provider: :anthropic)

      expect(BuildExtractionPrompt).to have_received(:call).with(
        subject_text: a_string_including(subject_page1),
        correction_text: a_string_including(correction_page1),
        specialty: subject_obj.specialty,
        skip_common: false
      )
    end

    it "calls AiClientFactory.build with the provider and api_key" do
      described_class.call(subject: subject_obj, api_key: "sk-test", provider: :anthropic)

      expect(AiClientFactory).to have_received(:build).with(provider: :anthropic, api_key: "sk-test")
    end

    it "calls the AI client with max_tokens: 16384" do
      described_class.call(subject: subject_obj, api_key: "sk-test", provider: :anthropic)

      expect(fake_client).to have_received(:call).with(
        hash_including(max_tokens: 16_384)
      )
    end

    it "returns [raw_response, parsed_data]" do
      result = described_class.call(subject: subject_obj, api_key: "sk-test", provider: :anthropic)

      expect(result).to be_an(Array)
      expect(result.length).to eq(2)

      raw_response, parsed_data = result

      expect(raw_response).to eq(ai_response)
      expect(parsed_data).to be_a(Hash)
    end

    it "parses the JSON response with common_parts" do
      _raw, parsed = described_class.call(subject: subject_obj, api_key: "sk-test", provider: :anthropic)

      expect(parsed).to have_key("common_parts")
      expect(parsed["common_parts"].first["questions"].first["number"]).to eq("1.1")
    end

    it "parses the JSON response with specific_parts" do
      _raw, parsed = described_class.call(subject: subject_obj, api_key: "sk-test", provider: :anthropic)

      expect(parsed).to have_key("specific_parts")
      expect(parsed["specific_parts"].first["questions"].first["number"]).to eq("2.1")
    end

    it "parses the JSON response with document_references" do
      _raw, parsed = described_class.call(subject: subject_obj, api_key: "sk-test", provider: :anthropic)

      expect(parsed).to have_key("document_references")
      expect(parsed["document_references"].length).to eq(2)
      expect(parsed["document_references"].first["type"]).to eq("DT")
    end
  end

  describe "error handling" do
    it "raises ParseError when JSON is invalid" do
      allow(fake_client).to receive(:call).and_return("not valid json at all")

      expect {
        described_class.call(subject: subject_obj, api_key: "sk-test", provider: :anthropic)
      }.to raise_error(ExtractQuestionsFromPdf::ParseError)
    end

    it "raises ParseError when response contains no JSON object" do
      allow(fake_client).to receive(:call).and_return("I cannot process this request")

      expect {
        described_class.call(subject: subject_obj, api_key: "sk-test", provider: :anthropic)
      }.to raise_error(ExtractQuestionsFromPdf::ParseError, /JSON introuvable/)
    end

    it "raises ParseError when JSON is malformed but contains braces" do
      allow(fake_client).to receive(:call).and_return('{"broken": json}')

      expect {
        described_class.call(subject: subject_obj, api_key: "sk-test", provider: :anthropic)
      }.to raise_error(ExtractQuestionsFromPdf::ParseError, /Impossible de parser/)
    end
  end
end
