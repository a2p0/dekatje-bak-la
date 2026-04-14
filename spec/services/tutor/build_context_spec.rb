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
end
