require "rails_helper"

RSpec.describe Tutor::FilterSpottingOutput do
  let(:user)         { create(:user) }
  let(:classroom)    { create(:classroom, owner: user) }
  let(:student)      { create(:student, classroom: classroom) }
  let(:exam_subject) { create(:subject, owner: user, status: :published) }
  let(:part)         { create(:part, subject: exam_subject) }
  let(:question)     { create(:question, part: part) }
  let(:conversation) do
    state = TutorState.new(
      current_phase:        "spotting",
      current_question_id:  question.id,
      concepts_mastered:    [],
      concepts_to_revise:   [],
      discouragement_level: 0,
      question_states:      {}, welcome_sent: false)
    create(:conversation, student: student, subject: exam_subject,
           lifecycle_state: "active", tutor_state: state)
  end
  let(:assistant_msg) do
    create(:message, conversation: conversation, role: :assistant,
           content: "test content", chunk_index: 0)
  end

  describe ".call" do
    context "when phase is spotting and content is clean" do
      it "returns ok with unchanged content" do
        result = described_class.call(
          message:    assistant_msg,
          llm_output: "Où penses-tu trouver les informations ?"
        )
        expect(result.ok?).to be true
        expect(result.value[:filtered]).to be false
        expect(assistant_msg.reload.content).to eq("Où penses-tu trouver les informations ?")
      end
    end

    context "when content contains a DT reference" do
      it "returns ok with filtered: true and replaces content with neutral relaunch" do
        result = described_class.call(
          message:    assistant_msg,
          llm_output: "Les données se trouvent dans DT1, tableau page 3."
        )
        expect(result.ok?).to be true
        expect(result.value[:filtered]).to be true
        reloaded = assistant_msg.reload.content
        expect(reloaded).to eq(
          "Reformule ta réponse sans mentionner de documents spécifiques ni de valeurs chiffrées. Où penses-tu trouver les informations ?"
        )
        expect(reloaded).not_to include("DT1")
      end
    end

    context "when content contains a DR reference" do
      it "filters DR2 reference" do
        result = described_class.call(
          message:    assistant_msg,
          llm_output: "Regarde dans DR2 pour compléter."
        )
        expect(result.value[:filtered]).to be true
      end
    end

    context "when content contains a numeric value with unit" do
      it "filters values like '56,73 l'" do
        result = described_class.call(
          message:    assistant_msg,
          llm_output: "La consommation est de 56,73 l pour ce trajet."
        )
        expect(result.value[:filtered]).to be true
      end

      it "filters values like '186 km'" do
        result = described_class.call(
          message:    assistant_msg,
          llm_output: "La distance est 186 km."
        )
        expect(result.value[:filtered]).to be true
      end

      it "filters values like '19600 N'" do
        result = described_class.call(
          message:    assistant_msg,
          llm_output: "La force appliquée est 19600 N."
        )
        expect(result.value[:filtered]).to be true
      end
    end

    context "when phase is not spotting" do
      it "returns ok immediately without checking patterns" do
        guiding_state = TutorState.new(
          current_phase:        "guiding",
          current_question_id:  question.id,
          concepts_mastered:    [],
          concepts_to_revise:   [],
          discouragement_level: 0,
          question_states:      {}, welcome_sent: false)
        guiding_conv = create(:conversation, student: student, subject: exam_subject,
                              lifecycle_state: "active", tutor_state: guiding_state)
        guiding_msg = create(:message, conversation: guiding_conv, role: :assistant,
                             content: "original", chunk_index: 0)

        result = described_class.call(
          message:    guiding_msg,
          llm_output: "Les données sont dans DT1, valeur 56,73 l."
        )
        expect(result.ok?).to be true
        expect(result.value[:filtered]).to be false
        expect(guiding_msg.reload.content).to eq("original")
      end
    end

    context "when message already has content" do
      it "persists the filtered neutral relaunch to message#content" do
        assistant_msg.update!(content: "Les données sont en DT2.")
        described_class.call(
          message:    assistant_msg,
          llm_output: "Les données sont en DT2."
        )
        expect(assistant_msg.reload.content).to eq(
          "Reformule ta réponse sans mentionner de documents spécifiques ni de valeurs chiffrées. Où penses-tu trouver les informations ?"
        )
      end
    end
  end
end