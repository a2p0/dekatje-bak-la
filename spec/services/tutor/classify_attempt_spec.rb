require "rails_helper"

RSpec.describe Tutor::ClassifyAttempt do
  let(:question) { create(:question, answer_type: "calcul") }

  context "when the answer has no structured_correction" do
    before { create(:answer, question: question, structured_correction: nil) }

    it "returns 'unknown'" do
      expect(
        described_class.call(student_content: "56,73 litres", question: question.reload)
      ).to eq("unknown")
    end
  end

  context "when structured_correction has no final_answers" do
    before do
      create(:answer, question: question, structured_correction: { "input_data" => [] })
    end

    it "returns 'unknown'" do
      expect(
        described_class.call(student_content: "56,73", question: question.reload)
      ).to eq("unknown")
    end
  end

  context "when student content matches a final_answer value" do
    before do
      create(:answer, question: question, structured_correction: {
        "final_answers" => [
          { "name" => "Consommation", "value" => "56,73 l" }
        ]
      })
    end

    it "returns 'correct' on exact value" do
      expect(
        described_class.call(student_content: "Je calcule 56,73 litres", question: question.reload)
      ).to eq("correct")
    end

    it "returns 'correct' on case-insensitive comparison" do
      expect(
        described_class.call(student_content: "C'est 56.73L au final", question: question.reload)
      ).to eq("correct")
    end

    it "returns 'correct' when comma replaced by dot" do
      expect(
        described_class.call(student_content: "56.73", question: question.reload)
      ).to eq("correct")
    end

    it "returns 'unknown' when value not present" do
      expect(
        described_class.call(student_content: "Je sais pas trop", question: question.reload)
      ).to eq("unknown")
    end

    it "returns 'unknown' when content is empty" do
      expect(
        described_class.call(student_content: "", question: question.reload)
      ).to eq("unknown")
    end
  end

  context "when multiple final_answers exist" do
    before do
      create(:answer, question: question, structured_correction: {
        "final_answers" => [
          { "name" => "Voiture",  "value" => "56,73 l"     },
          { "name" => "Camion",   "value" => "38,68 kWh"   }
        ]
      })
    end

    it "returns 'correct' if any value matches" do
      expect(
        described_class.call(student_content: "Pour le camion, j'ai trouvé 38,68 kWh", question: question.reload)
      ).to eq("correct")
    end

    it "returns 'unknown' if none matches" do
      expect(
        described_class.call(student_content: "Je crois 100 ou 200", question: question.reload)
      ).to eq("unknown")
    end
  end

  context "edge cases" do
    before do
      create(:answer, question: question, structured_correction: {
        "final_answers" => [ { "name" => "X", "value" => "1" } ]
      })
    end

    it "ignores too-short normalized values to avoid false positives" do
      # value "1" normalized stays "1" — too short, must not match arbitrarily
      expect(
        described_class.call(student_content: "Pour répondre 1 + 2 = 3, je dis 100", question: question.reload)
      ).to eq("unknown")
    end
  end

  context "when student_content is nil" do
    before do
      create(:answer, question: question, structured_correction: {
        "final_answers" => [ { "name" => "X", "value" => "56" } ]
      })
    end

    it "returns 'unknown' (defensive)" do
      expect(
        described_class.call(student_content: nil, question: question.reload)
      ).to eq("unknown")
    end
  end
end
