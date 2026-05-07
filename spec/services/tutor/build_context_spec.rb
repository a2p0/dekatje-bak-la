require "rails_helper"

RSpec.describe Tutor::BuildContext do
  let(:student) { create(:student) }
  let(:subject_record) { create(:subject) }
  let(:part) { create(:part, subject: subject_record, title: "Partie 1", objective_text: "Comparer modes de transport.") }
  let(:question) do
    create(:question,
      part: part,
      number: "1.2",
      label: "Calculer la consommation totale.",
      answer_type: "calcul")
  end
  let!(:answer) do
    create(:answer, question: question, correction_text: "Car = 56,73 l",
      structured_correction: {
        "input_data"         => [ { "name" => "consommation", "value" => "30,5 l/100km", "source" => "DT1" } ],
        "intermediate_steps" => [ "Identifier consommation et distance", "Multiplier × distance / 100" ],
        "final_answers"      => [ { "name" => "Conso totale", "value" => "56,73 L", "reasoning" => "30,5 × 186 / 100" } ]
      })
  end

  let(:conversation) do
    create(:conversation, student: student, subject: subject_record,
                          tutor_state: TutorState.default.with(current_question_id: question.id))
  end

  describe ".call" do
    it "produces a system_prompt with the 6 expected blocks" do
      result = described_class.call(
        conversation:  conversation,
        question:      question,
        student_input: "Je ne comprends pas",
        last_signal:   :dont_understand
      )

      expect(result.ok?).to be(true)
      prompt = result.value[:system_prompt]
      expect(prompt).to match(/POSTURE/)
      expect(prompt).to match(/CONTEXTE QUESTION/)
      expect(prompt).to match(/CORRECTION STRUCTURÉE/)
      expect(prompt).to match(/ÉTAT D'AIDE/)
      expect(prompt).to match(/CAP RÉSULTAT/)
      expect(prompt).to match(/ACTION ATTENDUE/)
    end

    it "exposes the budget with explicit counters" do
      result = described_class.call(conversation: conversation, question: question,
                                    student_input: "test", last_signal: :dont_understand)
      prompt = result.value[:system_prompt]
      expect(prompt).to match(/Formule.*donnée\s*:\s*NON/i)
      expect(prompt).to match(/Tentatives.*0/)
    end

    it "formulates the cap in positive form (OU)" do
      result = described_class.call(conversation: conversation, question: question,
                                    student_input: "test", last_signal: :dont_understand)
      prompt = result.value[:system_prompt]
      expect(prompt).to match(/tentatives\s*≥\s*2\s+OU\s+correction\s+vue/i)
    end

    it "injects the calibrated behavior_hint for the given signal+answer_type" do
      result = described_class.call(conversation: conversation, question: question,
                                    student_input: "Je ne comprends pas", last_signal: :dont_understand)
      prompt = result.value[:system_prompt]
      expect(prompt).to match(/Démarre direct/)
      expect(prompt).to match(/sous-tâche|formule/)
    end

    it "instructs the LLM to greet briefly when greeted is false" do
      result = described_class.call(conversation: conversation, question: question,
                                    student_input: nil, last_signal: :fresh_open)
      prompt = result.value[:system_prompt]
      expect(prompt).to match(/Salue brièvement/)
    end

    it "removes legacy 049 patterns" do
      result = described_class.call(conversation: conversation, question: question,
                                    student_input: "test", last_signal: :dont_understand)
      prompt = result.value[:system_prompt]

      expect(prompt).not_to match(/socratique/i)
      expect(prompt).not_to match(/70\s*%/)
      expect(prompt).not_to match(/verbe d'action/i)
      expect(prompt).not_to match(/spotting_type|spotting_data|guiding|validating/)
      expect(prompt).not_to match(/Indices.*1.*5/)
    end
  end
end
