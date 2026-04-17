require "rails_helper"

RSpec.describe TutorSimulation::StructuralMetrics do
  let(:user)            { create(:user) }
  let(:classroom)       { create(:classroom, owner: user) }
  let(:student)         { create(:student, classroom: classroom) }
  let(:exam_subject)    { create(:subject, owner: user, status: :published) }
  let(:part)            { create(:part, subject: exam_subject) }
  let(:question)        { create(:question, part: part) }

  let(:tutor_state) do
    TutorState.new(
      current_phase:        "guiding",
      current_question_id:  question.id,
      concepts_mastered:    [],
      concepts_to_revise:   [],
      discouragement_level: 0,
      question_states:      {
        question.id.to_s => QuestionState.new(
          step: 1, hints_used: 2, last_confidence: nil,
          error_types: [], completed_at: nil
        )
      }
    )
  end

  let(:conversation) do
    create(:conversation, student: student, subject: exam_subject,
           lifecycle_state: "active", tutor_state: tutor_state)
  end

  before do
    create(:message, conversation: conversation, role: :user,      content: "hello")
    create(:message, conversation: conversation, role: :assistant, content: "Bonjour, où sont les données ?")
    create(:message, conversation: conversation, role: :user,      content: "dans DT1")
    create(:message, conversation: conversation, role: :assistant, content: Tutor::FilterSpottingOutput::NEUTRAL_RELAUNCH)
  end

  subject(:metrics) { described_class.compute(conversation: conversation) }

  it "reports the final phase and rank" do
    expect(metrics[:final_phase]).to eq("guiding")
    expect(metrics[:phase_rank]).to eq(4)
  end

  it "computes the average tutor message length in words" do
    expect(metrics[:avg_message_length_words]).to be > 0
  end

  it "computes the open-question ratio (messages ending with '?')" do
    # both assistant messages end with "?": the greeting and the neutral relaunch
    expect(metrics[:open_question_ratio]).to eq(1.0)
  end

  it "counts regex intercepts (assistant messages replaced by the neutral relaunch)" do
    expect(metrics[:regex_intercepts]).to eq(1)
  end

  it "sums hints distributed across question_states" do
    expect(metrics[:hints_used]).to eq(2)
  end

  it "reports message counts per role" do
    expect(metrics[:message_count_assistant]).to eq(2)
    expect(metrics[:message_count_user]).to eq(2)
  end

  describe "#first_turn_with_transition (H1)" do
    subject(:metrics_with_phases) do
      described_class.compute(conversation: conversation, phase_per_turn: phase_per_turn)
    end

    context "when transition happens at turn 1" do
      let(:phase_per_turn) { %w[idle greeting reading] }

      it "returns 1" do
        expect(metrics_with_phases[:first_turn_with_transition]).to eq(1)
      end
    end

    context "when transition happens at turn 3" do
      let(:phase_per_turn) { %w[idle idle idle greeting] }

      it "returns 3" do
        expect(metrics_with_phases[:first_turn_with_transition]).to eq(3)
      end
    end

    context "when phase stays idle for the whole conversation" do
      let(:phase_per_turn) { %w[idle idle idle] }

      it "returns nil" do
        expect(metrics_with_phases[:first_turn_with_transition]).to be_nil
      end
    end

    context "when phase_per_turn is not provided (backward compat)" do
      it "returns nil" do
        expect(metrics[:first_turn_with_transition]).to be_nil
      end
    end
  end

  describe "#action_verb_ratio_guiding (H2)" do
    # Use isolated student + subject to avoid conflict with the global
    # conversation created in the outer `let(:conversation)` (student_id is
    # unique per subject on Conversation).
    let(:h2_student)  { create(:student, classroom: classroom) }
    let(:h2_subject)  { create(:subject, owner: user, status: :published) }

    let(:h2_tutor_state) do
      TutorState.new(
        current_phase:        "guiding",
        current_question_id:  nil,
        concepts_mastered:    [], concepts_to_revise: [], discouragement_level: 0,
        question_states:      {}
      )
    end

    let(:conversation_in_guiding) do
      create(:conversation, student: h2_student, subject: h2_subject,
             lifecycle_state: "active", tutor_state: h2_tutor_state)
    end

    subject(:metrics_with_phases) do
      described_class.compute(conversation: conversation_in_guiding, phase_per_turn: phase_per_turn)
    end

    context "when 2 of 3 guiding messages start with an action verb" do
      before do
        # 3 assistant messages, all emitted during guiding phase
        create(:message, conversation: conversation_in_guiding, role: :assistant, content: "Identifie la valeur de λ dans le DT1.")
        create(:message, conversation: conversation_in_guiding, role: :assistant, content: "Et si tu comparais cette valeur à la norme ?")
        create(:message, conversation: conversation_in_guiding, role: :assistant, content: "Calcule maintenant la résistance thermique.")
      end

      # 3 turns, so phase_per_turn has 4 elements; phases AFTER each turn = guiding
      let(:phase_per_turn) { %w[spotting guiding guiding guiding] }

      it "returns 0.67" do
        expect(metrics_with_phases[:action_verb_ratio_guiding]).to eq(0.67)
      end
    end

    context "when guiding phase is never reached" do
      before do
        create(:message, conversation: conversation_in_guiding, role: :assistant, content: "Bonjour, on commence ?")
      end

      let(:phase_per_turn) { %w[idle greeting] }

      it "returns nil" do
        expect(metrics_with_phases[:action_verb_ratio_guiding]).to be_nil
      end
    end

    context "when a guiding message starts with lowercase and leading whitespace" do
      before do
        create(:message, conversation: conversation_in_guiding, role: :assistant, content: "  identifie la valeur précise.")
      end

      let(:phase_per_turn) { %w[spotting guiding] }

      it "counts it as action verb (case-insensitive + trim)" do
        expect(metrics_with_phases[:action_verb_ratio_guiding]).to eq(1.0)
      end
    end

    context "when a guiding message starts with a verb followed by punctuation" do
      before do
        create(:message, conversation: conversation_in_guiding, role: :assistant, content: "Identifie, dans le DT1, la valeur.")
      end

      let(:phase_per_turn) { %w[spotting guiding] }

      it "counts it as action verb (strip trailing punctuation of first word)" do
        expect(metrics_with_phases[:action_verb_ratio_guiding]).to eq(1.0)
      end
    end

    context "when a guiding message contains an action verb in a later sentence" do
      before do
        create(:message, conversation: conversation_in_guiding, role: :assistant, content: "Je comprends ta difficulté. Repère la valeur de λ dans le DT1.")
      end

      let(:phase_per_turn) { %w[spotting guiding] }

      it "counts it (any sentence starting with an action verb)" do
        expect(metrics_with_phases[:action_verb_ratio_guiding]).to eq(1.0)
      end
    end

    context "when a guiding message has no sentence starting with an action verb" do
      before do
        create(:message, conversation: conversation_in_guiding, role: :assistant, content: "Tu fais du bon travail. C'est super.")
      end

      let(:phase_per_turn) { %w[spotting guiding] }

      it "returns 0.0" do
        expect(metrics_with_phases[:action_verb_ratio_guiding]).to eq(0.0)
      end
    end
  end

  describe "#dt_dr_leak_count_non_spotting" do
    let(:leak_student) { create(:student, classroom: classroom) }
    let(:leak_subject) { create(:subject, owner: user, status: :published) }
    let(:leak_tutor_state) do
      TutorState.new(
        current_phase:        "guiding",
        current_question_id:  nil,
        concepts_mastered:    [], concepts_to_revise: [], discouragement_level: 0,
        question_states:      {}
      )
    end
    let(:leak_conversation) do
      create(:conversation, student: leak_student, subject: leak_subject,
             lifecycle_state: "active", tutor_state: leak_tutor_state)
    end

    subject(:leak_metrics) do
      described_class.compute(conversation: leak_conversation, phase_per_turn: phase_per_turn)
    end

    context "with 2 messages mentioning DT1 in guiding phase" do
      before do
        create(:message, conversation: leak_conversation, role: :assistant, content: "Regarde DT1 pour la valeur.")
        create(:message, conversation: leak_conversation, role: :assistant, content: "Compare avec DR2 aussi.")
      end

      let(:phase_per_turn) { %w[spotting guiding guiding] }

      it "returns 2" do
        expect(leak_metrics[:dt_dr_leak_count_non_spotting]).to eq(2)
      end
    end

    context "with a DT1 mention during spotting phase" do
      before do
        create(:message, conversation: leak_conversation, role: :assistant, content: "Regarde DT1 pour la valeur.")
      end

      let(:phase_per_turn) { %w[idle spotting] }

      it "does not count it (leak only outside spotting)" do
        expect(leak_metrics[:dt_dr_leak_count_non_spotting]).to eq(0)
      end
    end
  end

  describe "#short_message_ratio" do
    let(:short_student) { create(:student, classroom: classroom) }
    let(:short_subject) { create(:subject, owner: user, status: :published) }
    let(:short_tutor_state) do
      TutorState.new(
        current_phase:        "guiding",
        current_question_id:  nil,
        concepts_mastered:    [], concepts_to_revise: [], discouragement_level: 0,
        question_states:      {}
      )
    end
    let(:short_conversation) do
      create(:conversation, student: short_student, subject: short_subject,
             lifecycle_state: "active", tutor_state: short_tutor_state)
    end

    subject(:short_metrics) do
      described_class.compute(conversation: short_conversation)
    end

    context "with 4 of 5 assistant messages under 60 words" do
      before do
        long_msg = ("mot " * 80).strip
        4.times do
          create(:message, conversation: short_conversation, role: :assistant, content: "Message court.")
        end
        create(:message, conversation: short_conversation, role: :assistant, content: long_msg)
      end

      it "returns 0.8" do
        expect(short_metrics[:short_message_ratio]).to eq(0.8)
      end
    end

    context "with no assistant messages" do
      it "returns 0.0 (sentinel)" do
        expect(short_metrics[:short_message_ratio]).to eq(0.0)
      end
    end
  end
end
