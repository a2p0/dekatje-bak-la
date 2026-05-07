require "rails_helper"

RSpec.describe Tutor::ChipsPresenter do
  # Force TutorState to load, which defines QuestionTrace at the top level
  before(:all) { _ = TutorState }

  describe ".call" do
    let(:trace) { QuestionTrace.empty(question_id: 1) }

    it "returns the calcul/fresh chips for a fresh trace on a calcul question" do
      chips = described_class.call(trace: trace, answer_type: "calcul")
      expect(chips).to be_an(Array)
      expect(chips.length).to be_between(3, 4).inclusive
      labels = chips.map { |c| c[:label] }
      expect(labels).to include("C'est quoi la formule ?")
    end

    it "returns the qcm/fresh chips for qcm" do
      chips = described_class.call(trace: trace, answer_type: "qcm")
      expect(chips.map { |c| c[:label] }).to include("Explique les options")
    end

    it "marks 'Donne le résultat' as disabled when cap is active" do
      events = [ { "type" => "student_attempt", "verdict" => "incorrect", "source" => "llm_message",
                   "at" => "2026-05-06T10:00:00Z", "content" => "5673" } ]
      trace_one_attempt = QuestionTrace.new(question_id: 1, events: events.freeze)

      chips = described_class.call(trace: trace_one_attempt, answer_type: "calcul")
      result_chip = chips.find { |c| c[:label] == "Donne le résultat" }
      expect(result_chip).not_to be_nil
      expect(result_chip[:disabled]).to be(true)
      expect(result_chip[:tooltip]).to include("Essaie")
    end

    it "marks 'Donne le résultat' as enabled when cap is lifted (2 attempts)" do
      events = 2.times.map do
        { "type" => "student_attempt", "verdict" => "incorrect", "source" => "llm_message",
          "at" => "2026-05-06T10:00:00Z", "content" => "5673" }
      end
      trace_two_attempts = QuestionTrace.new(question_id: 1, events: events.freeze)

      chips = described_class.call(trace: trace_two_attempts, answer_type: "calcul")
      result_chip = chips.find { |c| c[:label] == "Donne le résultat" }
      expect(result_chip[:disabled]).to be(false)
    end

    it "covers all 7 answer_types × 5 phases without raising" do
      answer_types = %w[calcul identification justification representation qcm verification conclusion]
      phases       = %i[fresh armed debug close done]

      answer_types.each do |at|
        phases.each do |ph|
          # Build a trace that yields the desired phase via DerivePhase semantics.
          chips = described_class.for_phase(answer_type: at, phase: ph, cap_active: false)
          expect(chips).to be_an(Array), "missing chips for #{at}/#{ph}"
        end
      end
    end
  end
end
