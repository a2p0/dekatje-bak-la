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
                resolution_rate:                   0.8,
                cap_violations:                    0,
                mean_help_steps_before_resolution: 2.0,
                proactive_help_rate:               0.5,
                correct_attempts_after_help_rate:  0.75,
                attempts_per_question:             3.0,
                correction_view_rate:              0.25,
                mean_turns_to_resolution:          4.0
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
      expect(md).to include("Taux de résolution")
      expect(md).to include("0.8")
      expect(md).to include("Violations CAP")
    end

    it "renders the 5 qualitative criteria" do
      md = described_class.new(simulation_data).to_markdown

      expect(md).to include("Non-divulgation")
      expect(md).to include("Guidage progressif")
      expect(md).to include("Bienveillance")
      expect(md).to include("Focalisation")
      expect(md).to include("Respect du process")
    end

    context "when evaluation is marked skipped (SKIP_JUDGE=1)" do
      let(:skipped_data) do
        deep = Marshal.load(Marshal.dump(simulation_data))
        deep[:results][0][:profiles][0][:evaluation] = { "skipped" => true }
        deep
      end

      it "renders a 'Juge désactivé' notice instead of the scores table" do
        md = described_class.new(skipped_data).to_markdown

        expect(md).to include("Juge désactivé")
        expect(md).not_to include("Non-divulgation")
        expect(md).not_to include("5/5")
      end
    end

    it "renders the 062 structural metrics per profile" do
      md = described_class.new(simulation_data).to_markdown

      expect(md).to include("Taux aide proactive")
      expect(md).to include("Tentatives par question")
      expect(md).to include("Taux consultation correction")
      expect(md).to include("Tours moyens avant résolution")
    end

    it "includes average resolution_rate in global summary" do
      mixed_data = Marshal.load(Marshal.dump(simulation_data))
      mixed_data[:results][0][:profiles] << Marshal.load(Marshal.dump(mixed_data[:results][0][:profiles][0]))
      mixed_data[:results][0][:profiles][0][:profile_label] = "Profil A"
      mixed_data[:results][0][:profiles][1][:profile_label] = "Profil B"
      mixed_data[:results][0][:profiles][0][:structural_metrics][:resolution_rate] = 0.6
      mixed_data[:results][0][:profiles][1][:structural_metrics][:resolution_rate] = 1.0

      md = described_class.new(mixed_data).to_markdown

      expect(md).to include("Taux de résolution")
      expect(md).to match(/Taux de résolution.*0\.8/m)
    end
  end
end
