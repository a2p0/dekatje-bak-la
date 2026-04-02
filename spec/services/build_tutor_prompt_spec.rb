# spec/services/build_tutor_prompt_spec.rb
require "rails_helper"

RSpec.describe BuildTutorPrompt do
  let(:user) { create(:user, tutor_prompt_template: nil) }
  let(:subject_record) { create(:subject, owner: user, specialty: :SIN) }
  let(:part) { create(:part, subject: subject_record, title: "Partie 1", objective_text: "Comparer les transports") }
  let(:question) { create(:question, part: part, label: "Calculer la consommation", context_text: "Distance 186 km") }
  let!(:answer) { create(:answer, question: question, correction_text: "56,73 litres") }
  let(:student) { create(:student) }

  describe ".call" do
    it "returns the interpolated default template" do
      result = described_class.call(question: question, student: student)

      expect(result).to include("SIN")
      expect(result).to include("Partie 1")
      expect(result).to include("Comparer les transports")
      expect(result).to include("Calculer la consommation")
      expect(result).to include("Distance 186 km")
      expect(result).to include("56,73 litres")
      expect(result).to include("ne donne JAMAIS la reponse directement")
    end

    it "uses teacher custom template when set" do
      user.update!(tutor_prompt_template: "Custom prompt for %{specialty} — %{question_label}")

      result = described_class.call(question: question, student: student)

      expect(result).to include("Custom prompt for SIN")
      expect(result).to include("Calculer la consommation")
      expect(result).not_to include("ne donne JAMAIS")
    end

    it "appends student insights when they exist" do
      create(:student_insight,
        student: student,
        subject: subject_record,
        insight_type: "mastered",
        concept: "energie primaire",
        text: "Bien compris"
      )

      result = described_class.call(question: question, student: student)

      expect(result).to include("Historique de l'eleve")
      expect(result).to include("[mastered] energie primaire: Bien compris")
    end

    it "does not include insights section when no insights exist" do
      result = described_class.call(question: question, student: student)

      expect(result).not_to include("Historique de l'eleve")
    end

    it "handles question without answer gracefully" do
      question_no_answer = create(:question, part: part, label: "Question sans reponse")

      result = described_class.call(question: question_no_answer, student: student)

      expect(result).to include("Question sans reponse")
    end

    context "spotting context" do
      let(:classroom) { create(:classroom, owner: user) }
      let(:student_with_session) { create(:student, classroom: classroom) }

      let(:tutored_session) do
        create(:student_session,
          student: student_with_session,
          subject: subject_record,
          mode: :tutored,
          tutor_state: {
            "question_states" => {
              question.id.to_s => {
                "step" => "feedback",
                "spotting" => {
                  "task_type_correct" => false,
                  "task_type_answer" => "text",
                  "sources_missed" => [
                    { "source" => "DT2", "location" => "tableau des caracteristiques" }
                  ]
                }
              }
            }
          }
        )
      end

      it "includes missed sources and guidance when student missed sources" do
        tutored_session

        result = described_class.call(question: question, student: student_with_session)

        expect(result).to include("Sources manquee")
        expect(result).to include("DT2")
        expect(result).to include("Guide l'eleve vers cette source")
      end

      it "includes task type mismatch guidance when student got task type wrong" do
        tutored_session

        result = described_class.call(question: question, student: student_with_session)

        expect(result).to include("Rediger une reponse")
        expect(result).to include("Guide-le sur ce point")
      end

      it "includes positive message when student identified all sources correctly" do
        create(:student_session,
          student: student_with_session,
          subject: subject_record,
          mode: :tutored,
          tutor_state: {
            "question_states" => {
              question.id.to_s => {
                "step" => "feedback",
                "spotting" => {
                  "task_type_correct" => true,
                  "task_type_answer" => "calculation",
                  "sources_missed" => []
                }
              }
            }
          }
        )

        result = described_class.call(question: question, student: student_with_session)

        expect(result).to include("correctement identifie toutes les sources de donnees")
      end

      it "does not include spotting context section when no spotting data exists" do
        create(:student_session,
          student: student_with_session,
          subject: subject_record,
          mode: :tutored,
          tutor_state: {}
        )

        result = described_class.call(question: question, student: student_with_session)

        expect(result).not_to include("Resultat du reperage")
      end

      it "does not include spotting context section in autonomous mode" do
        create(:student_session,
          student: student_with_session,
          subject: subject_record,
          mode: :autonomous,
          tutor_state: {
            "question_states" => {
              question.id.to_s => {
                "spotting" => {
                  "task_type_correct" => true,
                  "sources_missed" => []
                }
              }
            }
          }
        )

        result = described_class.call(question: question, student: student_with_session)

        expect(result).not_to include("Resultat du reperage")
      end
    end
  end
end
