require "rails_helper"

RSpec.describe Tutor::BehaviorHints do
  describe ".for" do
    let(:budget) do
      { formule_given: false, value_given: false, calc_given: false, result_given: false,
        attempts_count: 0, viewed_correction: false }
    end

    it "returns the fresh-open hint when greeted is false" do
      hint = described_class.for(signal: :fresh_open, answer_type: :calcul, budget: budget)
      expect(hint).to include("Salue brièvement")
    end

    it "returns wrong_attempt hint for calcul" do
      hint = described_class.for(
        signal: :wrong_attempt,
        answer_type: :calcul,
        budget: budget.merge(attempts_count: 1)
      )
      expect(hint).to match(/pas ça/i)
      expect(hint).to match(/calcul|détail|unité/i)
    end

    it "differs by answer_type for the same signal" do
      hint_calcul = described_class.for(signal: :wrong_attempt, answer_type: :calcul, budget: budget)
      hint_qcm    = described_class.for(signal: :wrong_attempt, answer_type: :qcm,    budget: budget)
      expect(hint_calcul).not_to eq(hint_qcm)
    end

    it "produces a non-empty hint for any (signal, answer_type) combo (fallback)" do
      signals      = %i[fresh_open opened_after_data_hints opened_after_correction
                        dont_understand wrong_attempt correct_attempt
                        chip_formule chip_valeur chip_calcul chip_resultat
                        navigation_arrival]
      answer_types = %i[calcul identification justification representation qcm verification conclusion]

      signals.each do |s|
        answer_types.each do |at|
          hint = described_class.for(signal: s, answer_type: at, budget: budget)
          expect(hint).to be_a(String).and(satisfy { |x| x.length.positive? })
        end
      end
    end

    it "returns the cap-locked hint for chip_resultat when cap is active" do
      hint = described_class.for(
        signal: :chip_resultat,
        answer_type: :calcul,
        budget: budget.merge(attempts_count: 1, viewed_correction: false)
      )
      expect(hint).to match(/refuse|propose-lui|tentative|correction/i)
    end
  end
end
