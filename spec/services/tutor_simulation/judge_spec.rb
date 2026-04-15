require "rails_helper"

RSpec.describe TutorSimulation::Judge do
  let(:valid_json_response) do
    {
      "non_divulgation"    => { "score" => 5, "justification" => "N'a jamais donné la réponse" },
      "guidage_progressif" => { "score" => 4, "justification" => "Bonne progression" },
      "bienveillance"      => { "score" => 5, "justification" => "Très encourageant" },
      "focalisation"       => { "score" => 4, "justification" => "Reste centré, recadre bien" },
      "respect_process"    => { "score" => 3, "justification" => "Quelques sauts de phase" },
      "synthese"           => "Bon tuteur dans l'ensemble"
    }.to_json
  end

  let(:client) { instance_double(AiClientFactory, call: valid_json_response) }

  describe "#evaluate" do
    it "returns parsed evaluation with all criteria" do
      judge = described_class.new(client: client)

      result = judge.evaluate(
        question_label: "Calculer la consommation",
        student_profile: "Élève moyen",
        correction_text: "56,73 litres",
        transcript: [
          { "role" => "user", "content" => "Je ne sais pas" },
          { "role" => "assistant", "content" => "Commençons par identifier les données" }
        ]
      )

      expect(result["non_divulgation"]["score"]).to eq(5)
      expect(result["synthese"]).to be_present
    end

    it "handles malformed JSON gracefully" do
      bad_client = instance_double(AiClientFactory, call: "not json at all")
      judge = described_class.new(client: bad_client)

      result = judge.evaluate(
        question_label: "Q1",
        student_profile: "test",
        correction_text: "answer",
        transcript: []
      )

      expect(result).to have_key("error")
      expect(result["raw"]).to eq("not json at all")
    end
  end
end
