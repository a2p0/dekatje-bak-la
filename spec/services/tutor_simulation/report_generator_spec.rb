require "rails_helper"

RSpec.describe TutorSimulation::ReportGenerator do
  let(:simulation_data) do
    {
      subject_id:       1,
      subject_title:    "BAC STI2D Métropole 2025",
      timestamp:        "2026-04-03T10:00:00+00:00",
      max_turns:        3,
      tutor_provider:   :anthropic,
      tutor_model:      "claude-sonnet-4-6",
      student_provider: :anthropic,
      student_model:    "claude-sonnet-4-6",
      judge_provider:   :anthropic,
      judge_model:      "claude-sonnet-4-6",
      results: [
        {
          question_id:     42,
          question_number: "1.1",
          question_label:  "Calculer la consommation",
          points:          2.0,
          answer_type:     "calculation",
          correction:      "56,73 litres",
          profiles: [
            {
              profile:       "eleve_moyen",
              profile_label: "Élève moyen",
              transcript: [
                { "role" => "user", "content" => "Euh je sais pas trop" },
                { "role" => "assistant", "content" => "Commençons par les données" }
              ],
              evaluation: {
                "non_divulgation"    => { "score" => 5, "justification" => "OK" },
                "guidage_progressif" => { "score" => 4, "justification" => "Bien" },
                "bienveillance"      => { "score" => 5, "justification" => "Très bien" },
                "pertinence"         => { "score" => 4, "justification" => "OK" },
                "adaptation"         => { "score" => 3, "justification" => "Moyen" },
                "resistance_derive"  => { "score" => 5, "justification" => "Bien" },
                "synthese"           => "Bon tuteur"
              }
            }
          ]
        }
      ]
    }
  end

  describe "#to_json" do
    it "returns valid JSON" do
      generator = described_class.new(simulation_data)
      json = generator.to_json
      parsed = JSON.parse(json)

      expect(parsed["subject_title"]).to eq("BAC STI2D Métropole 2025")
      expect(parsed["results"].size).to eq(1)
    end
  end

  describe "#to_markdown" do
    it "includes all sections" do
      generator = described_class.new(simulation_data)
      md = generator.to_markdown

      expect(md).to include("# Simulation Tuteur")
      expect(md).to include("BAC STI2D Métropole 2025")
      expect(md).to include("Calculer la consommation")
      expect(md).to include("Élève moyen")
      expect(md).to include("5/5")
      expect(md).to include("Résumé global")
      expect(md).to include("Score moyen global")
    end
  end
end
