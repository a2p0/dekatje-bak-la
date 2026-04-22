require "rails_helper"

RSpec.describe Tutor::BuildContext do
  let(:user)          { create(:user) }
  let(:classroom)     { create(:classroom, owner: user) }
  let(:student)       { create(:student, classroom: classroom) }
  let(:exam_subject)  { create(:subject, owner: user, status: :published, specialty: :SIN) }
  let!(:cs)           { create(:classroom_subject, classroom: classroom, subject: exam_subject) }
  let(:part)          { create(:part, subject: exam_subject, title: "Partie 1", objective_text: "Analyser le système.") }
  let(:question)      { create(:question, part: part, label: "Calculer la puissance.", context_text: "P = U × I") }
  let!(:answer)       { create(:answer, question: question, correction_text: "P = 230 × 2 = 460 W") }
  let(:conversation) do
    create(:conversation, student: student, subject: exam_subject,
           tutor_state: TutorState.default)
  end

  subject(:result) do
    described_class.call(
      conversation:  conversation,
      question:      question,
      student_input: "<student_input>Je ne sais pas.</student_input>"
    )
  end

  it "returns ok" do
    expect(result.ok?).to be true
  end

  it "includes system prompt with pedagogical rules" do
    expect(result.value[:system_prompt]).to include("Ne jamais donner la réponse directement")
    expect(result.value[:system_prompt]).to include("Maximum 60 mots par message")
  end

  it "includes subject context in system prompt" do
    expect(result.value[:system_prompt]).to include("Calculer la puissance.")
    expect(result.value[:system_prompt]).to include("P = U × I")
  end

  it "includes confidential correction in system prompt" do
    expect(result.value[:system_prompt]).to include("P = 230 × 2 = 460 W")
  end

  it "includes learner model from TutorState" do
    expect(result.value[:system_prompt]).to include("Phase courante")
  end

  it "instructs the LLM to greet on the first message" do
    expect(result.value[:system_prompt]).to include("DÉMARRAGE DE CONVERSATION")
    expect(result.value[:system_prompt]).to include("greeting")
  end

  it "includes the mandatory tool-usage instructions (FR-004)" do
    prompt = result.value[:system_prompt]
    expect(prompt).to include("UTILISATION DES OUTILS — OBLIGATOIRE")
    expect(prompt).to include("transition")
    expect(prompt).to include("update_learner_model")
    expect(prompt).to include("request_hint")
    expect(prompt).to include("evaluate_spotting")
  end

  it "returns a messages array" do
    expect(result.value[:messages]).to be_an(Array)
  end

  it "limits messages to last 40" do
    45.times { |i| create(:message, conversation: conversation, role: :user, content: "msg #{i}") }
    r = described_class.call(
      conversation:  conversation,
      question:      question,
      student_input: "<student_input>test</student_input>"
    )
    expect(r.value[:messages].length).to be <= 40
  end

  context "en phase spotting" do
    let(:spotting_conversation) do
      spotting_state = TutorState.new(
        current_phase:        "spotting",
        current_question_id:  question.id,
        concepts_mastered:    [],
        concepts_to_revise:   [],
        discouragement_level: 0,
        question_states:      {
          question.id.to_s => QuestionState.new(
            step: "initial", hints_used: 0, last_confidence: nil,
            error_types: [], completed_at: nil
          )
        }
      )
      create(:conversation, student: student, subject: exam_subject,
             lifecycle_state: "active", tutor_state: spotting_state)
    end

    subject(:result) do
      described_class.call(
        conversation:  spotting_conversation,
        question:      question,
        student_input: "Je pense que c'est dans l'énoncé."
      )
    end

    it "includes the spotting phase header" do
      expect(result.value[:system_prompt]).to include("PHASE REPÉRAGE")
    end

    it "includes the 3-level relaunch instructions" do
      expect(result.value[:system_prompt]).to include("Niveau 1")
      expect(result.value[:system_prompt]).to include("Niveau 2")
      expect(result.value[:system_prompt]).to include("Niveau 3")
    end

    it "includes the forbidden patterns warning" do
      expect(result.value[:system_prompt]).to include("INTERDIT ABSOLU")
      expect(result.value[:system_prompt]).to include("Mentionner des noms précis de documents")
    end

    it "includes the forced_reveal instruction after 3 failed relaunches" do
      expect(result.value[:system_prompt]).to include("forced_reveal")
    end

    it "does NOT include the spotting section when phase is not spotting" do
      reading_state = TutorState.new(
        current_phase:        "reading",
        current_question_id:  nil,
        concepts_mastered:    [],
        concepts_to_revise:   [],
        discouragement_level: 0,
        question_states:      {}
      )
      reading_conv = create(:conversation, student: student, subject: exam_subject,
                             lifecycle_state: "active", tutor_state: reading_state)
      r = described_class.call(
        conversation:  reading_conv,
        question:      question,
        student_input: "test"
      )
      expect(r.value[:system_prompt]).not_to include("PHASE REPÉRAGE")
    end
  end

  describe "structured_correction section (043)" do
    let(:structured) do
      {
        "input_data" => [
          { "name" => "épaisseur laine de roche", "value" => "0,18 m", "source" => "DTS1" },
          { "name" => "conductivité laine de roche", "value" => "0,034 W·m-1·K-1", "source" => "DTS1" }
        ],
        "final_answers" => [
          { "name" => "résistance thermique laine de roche", "value" => "5,29 m²·K·W-1",
            "reasoning" => "R = e/λ = 0,18/0,034" }
        ],
        "intermediate_steps" => [
          "Identifier les composants de la paroi dans le DTS1",
          "Appliquer R = e/λ pour chaque couche"
        ],
        "common_errors" => [
          { "error" => "Oublier la conversion cm→m", "remediation" => "Toujours convertir en mètres" }
        ]
      }
    end

    context "when structured_correction is present" do
      before { answer.update!(structured_correction: structured) }

      it "includes the [CORRECTION STRUCTURÉE] header" do
        expect(result.value[:system_prompt]).to include("[CORRECTION STRUCTURÉE — GUIDE PÉDAGOGIQUE]")
      end

      it "includes the [DONNÉES DU SUJET] section with input_data values" do
        prompt = result.value[:system_prompt]
        expect(prompt).to include("[DONNÉES DU SUJET — TU PEUX LES CITER LIBREMENT")
        expect(prompt).to include("épaisseur laine de roche : 0,18 m [source : DTS1]")
      end

      it "includes the [RÉSULTATS FINAUX] section with final_answer names and values" do
        prompt = result.value[:system_prompt]
        expect(prompt).to include("[RÉSULTATS FINAUX — NE JAMAIS RÉVÉLER")
        expect(prompt).to include("résistance thermique laine de roche = 5,29 m²·K·W-1")
        expect(prompt).to include("R = e/λ = 0,18/0,034")
      end

      it "includes the [ÉTAPES DE RAISONNEMENT] section in order" do
        prompt = result.value[:system_prompt]
        expect(prompt).to include("[ÉTAPES DE RAISONNEMENT ATTENDUES]")
        expect(prompt).to include("1. Identifier les composants")
        expect(prompt).to include("2. Appliquer R = e/λ")
      end

      it "includes the [ERREURS FRÉQUENTES] section with error and remediation" do
        prompt = result.value[:system_prompt]
        expect(prompt).to include("[ERREURS FRÉQUENTES À SURVEILLER]")
        expect(prompt).to include("Oublier la conversion cm→m")
        expect(prompt).to include("Toujours convertir en mètres")
      end
    end

    context "when structured_correction is nil (backward compat)" do
      before { answer.update!(structured_correction: nil) }

      it "does NOT include the [CORRECTION STRUCTURÉE] header" do
        expect(result.value[:system_prompt]).not_to include("[CORRECTION STRUCTURÉE")
      end

      it "still falls back to the legacy correction_text section" do
        expect(result.value[:system_prompt]).to include("CORRECTION CONFIDENTIELLE")
        expect(result.value[:system_prompt]).to include("P = 230 × 2 = 460 W")
      end
    end

    context "when structured_correction has only input_data" do
      before { answer.update!(structured_correction: { "input_data" => structured["input_data"] }) }

      it "includes the input_data section but skips empty ones" do
        prompt = result.value[:system_prompt]
        expect(prompt).to include("[DONNÉES DU SUJET")
        expect(prompt).not_to include("[RÉSULTATS FINAUX")
        expect(prompt).not_to include("[ÉTAPES DE RAISONNEMENT")
        expect(prompt).not_to include("[ERREURS FRÉQUENTES")
      end
    end
  end

  context "when the question belongs to a common part (Part#subject_id is nil)" do
    let(:exam_session) { create(:exam_session, owner: user, title: "Sujet CIME") }
    let(:exam_subject) do
      create(:subject,
             owner:        user,
             exam_session: exam_session,
             status:       :published,
             specialty:    :SIN)
    end
    let(:common_part) do
      # Common part is owned by the exam_session, not a subject
      create(:part, subject: nil, exam_session: exam_session,
             title: "Partie commune", objective_text: "Objectif commun")
    end
    let(:common_question) do
      create(:question, part: common_part, label: "Question commune")
    end
    let!(:common_answer) do
      create(:answer, question: common_question, correction_text: "Réponse commune")
    end
    let(:conversation) do
      create(:conversation, student: student, subject: exam_subject,
             tutor_state: TutorState.default)
    end

    it "resolves the subject from the conversation, not from part.subject" do
      expect(common_part.subject).to be_nil

      result = described_class.call(
        conversation:  conversation,
        question:      common_question,
        student_input: "test"
      )

      expect(result.ok?).to be true
      expect(result.value[:system_prompt]).to include("Sujet CIME")
      expect(result.value[:system_prompt]).to include("SIN")
    end
  end
end
