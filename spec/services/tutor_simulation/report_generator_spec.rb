require "rails_helper"

RSpec.describe TutorSimulation::ReportGenerator do
  let(:simulation_data) do
    {
      subject_id:       1,
      subject_title:    "BAC STI2D Métropole 2025",
      timestamp:        "2026-04-15T10:00:00+00:00",
      max_turns:        3,
      tutor_provider:   "openrouter (real pipeline)",
      tutor_model:      "openai/gpt-4o-mini",
      student_provider: "openrouter",
      student_model:    "openai/gpt-4o-mini",
      judge_provider:   "openrouter",
      judge_model:      "anthropic/claude-sonnet-4",
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
                { "role" => "user",      "content" => "Euh je sais pas trop" },
                { "role" => "assistant", "content" => "Commençons par les données ?" }
              ],
              structural_metrics: {
                final_phase:              "spotting",
                phase_rank:               3,
                avg_message_length_words: 25.0,
                open_question_ratio:      0.8,
                regex_intercepts:         0,
                hints_used:               1,
                message_count_assistant:  3,
                message_count_user:       3
              },
              evaluation: {
                "non_divulgation"    => { "score" => 5, "justification" => "OK" },
                "guidage_progressif" => { "score" => 4, "justification" => "Bien" },
                "bienveillance"      => { "score" => 5, "justification" => "Très bien" },
                "focalisation"       => { "score" => 4, "justification" => "OK" },
                "respect_process"    => { "score" => 3, "justification" => "Moyen" },
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
    end

    it "renders the structural metrics block" do
      md = described_class.new(simulation_data).to_markdown

      expect(md).to include("Métriques structurelles")
      expect(md).to include("Phase finale")
      expect(md).to include("spotting")
      expect(md).to include("Ratio messages se terminant par")
    end

    it "renders the 5 qualitative criteria" do
      md = described_class.new(simulation_data).to_markdown

      expect(md).to include("Non-divulgation")
      expect(md).to include("Guidage progressif")
      expect(md).to include("Bienveillance")
      expect(md).to include("Focalisation")
      expect(md).to include("Respect du process")
    end
  end
end
