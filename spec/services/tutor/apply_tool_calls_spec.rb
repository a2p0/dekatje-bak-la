require "rails_helper"

RSpec.describe Tutor::ApplyToolCalls do
  let(:user)         { create(:user) }
  let(:classroom)    { create(:classroom, owner: user) }
  let(:student)      { create(:student, classroom: classroom) }
  let(:exam_subject) { create(:subject, owner: user, status: :published) }

  def make_conversation(phase: "reading", question_id: nil, extra_state: {})
    state = TutorState.new(
      current_phase:        phase,
      current_question_id:  question_id,
      concepts_mastered:    [],
      concepts_to_revise:   [],
      discouragement_level: 0,
      question_states:      extra_state, welcome_sent: false, last_activity_at: nil)
    create(:conversation, student: student, subject: exam_subject, tutor_state: state)
  end

  describe "tool: transition" do
    it "allows idle → greeting (FR-009)" do
      conv = make_conversation(phase: "idle")
      result = described_class.call(
        conversation: conv,
        tool_calls: [ { name: "transition", args: { "phase" => "greeting" } } ]
      )
      expect(result.ok?).to be true
      expect(result.value[:updated_tutor_state].current_phase).to eq("greeting")
    end

    it "silently ignores idle → reading (only greeting is allowed from idle)" do
      conv = make_conversation(phase: "idle")
      result = described_class.call(
        conversation: conv,
        tool_calls: [ { name: "transition", args: { "phase" => "reading" } } ]
      )
      expect(result.ok?).to be true
      expect(result.value[:updated_tutor_state].current_phase).to eq("idle")
    end

    it "allows a valid phase transition" do
      conv = make_conversation(phase: "enonce", question_id: 1)
      result = described_class.call(
        conversation: conv,
        tool_calls: [ { name: "transition", args: { "phase" => "spotting_type", "question_id" => 1 } } ]
      )
      expect(result.ok?).to be true
      expect(result.value[:updated_tutor_state].current_phase).to eq("spotting_type")
      expect(result.value[:updated_tutor_state].current_question_id).to eq(1)
    end

    it "silently ignores an invalid phase string (state unchanged)" do
      conv = make_conversation(phase: "reading")
      result = described_class.call(
        conversation: conv,
        tool_calls: [ { name: "transition", args: { "phase" => "nonexistent_phase" } } ]
      )
      expect(result.ok?).to be true
      expect(result.value[:updated_tutor_state].current_phase).to eq("reading")
    end

    it "silently ignores a forbidden transition (state unchanged)" do
      conv = make_conversation(phase: "guiding", question_id: 1)
      result = described_class.call(
        conversation: conv,
        tool_calls: [ { name: "transition", args: { "phase" => "greeting", "question_id" => 1 } } ]
      )
      expect(result.ok?).to be true
      expect(result.value[:updated_tutor_state].current_phase).to eq("guiding")
    end
  end

  describe "tool: update_learner_model" do
    it "adds a mastered concept" do
      conv = make_conversation
      result = described_class.call(
        conversation: conv,
        tool_calls: [ { name: "update_learner_model", args: { "concept_mastered" => "énergie primaire" } } ]
      )
      expect(result.ok?).to be true
      expect(result.value[:updated_tutor_state].concepts_mastered).to include("énergie primaire")
    end

    it "clamps discouragement_delta between 0 and 3" do
      conv = make_conversation
      result = described_class.call(
        conversation: conv,
        tool_calls: [ { name: "update_learner_model", args: { "discouragement_delta" => -5 } } ]
      )
      expect(result.value[:updated_tutor_state].discouragement_level).to eq(0)

      state3 = TutorState.new(
        current_phase: "reading", current_question_id: nil,
        concepts_mastered: [], concepts_to_revise: [],
        discouragement_level: 3, question_states: {}, welcome_sent: false, last_activity_at: nil)
      other_student = create(:student, classroom: classroom)
      conv3 = create(:conversation, student: other_student, subject: exam_subject, tutor_state: state3)
      result3 = described_class.call(
        conversation: conv3,
        tool_calls: [ { name: "update_learner_model", args: { "discouragement_delta" => 5 } } ]
      )
      expect(result3.value[:updated_tutor_state].discouragement_level).to eq(3)
    end
  end

  describe "tool: request_hint" do
    it "increments hints_used monotonically from 0 to 1" do
      qs = QuestionState.new(phase: "enonce", step: "initial", hints_used: 0, last_confidence: nil, error_types: [], completed_at: nil, intro_seen: false)
      conv = make_conversation(phase: "guiding", question_id: 7, extra_state: { "7" => qs })
      result = described_class.call(
        conversation: conv,
        tool_calls: [ { name: "request_hint", args: { "level" => 1 } } ]
      )
      expect(result.ok?).to be true
      expect(result.value[:updated_tutor_state].question_states["7"].hints_used).to eq(1)
    end

    it "silently ignores skipped hint levels (hints_used unchanged)" do
      qs = QuestionState.new(phase: "enonce", step: "initial", hints_used: 1, last_confidence: nil, error_types: [], completed_at: nil, intro_seen: false)
      conv = make_conversation(phase: "guiding", question_id: 7, extra_state: { "7" => qs })
      result = described_class.call(
        conversation: conv,
        tool_calls: [ { name: "request_hint", args: { "level" => 3 } } ]
      )
      expect(result.ok?).to be true
      expect(result.value[:updated_tutor_state].question_states["7"].hints_used).to eq(1)
    end

    it "silently ignores hint above max (5)" do
      qs = QuestionState.new(phase: "enonce", step: "initial", hints_used: 5, last_confidence: nil, error_types: [], completed_at: nil, intro_seen: false)
      conv = make_conversation(phase: "guiding", question_id: 7, extra_state: { "7" => qs })
      result = described_class.call(
        conversation: conv,
        tool_calls: [ { name: "request_hint", args: { "level" => 6 } } ]
      )
      expect(result.ok?).to be true
      expect(result.value[:updated_tutor_state].question_states["7"].hints_used).to eq(5)
    end
  end

  describe "tool: evaluate_spotting" do
    it "silently ignores evaluate_spotting outside spotting phase (state unchanged)" do
      conv = make_conversation(phase: "guiding", question_id: 1)
      result = described_class.call(
        conversation: conv,
        tool_calls: [ {
          name: "evaluate_spotting",
          args: {
            "task_type_identified" => "calcul",
            "sources_identified"   => [ "DT1" ],
            "missing_sources"      => [],
            "extra_sources"        => [],
            "feedback_message"     => "Bien.",
            "relaunch_prompt"      => "",
            "outcome"              => "success"
          }
        } ]
      )
      expect(result.ok?).to be true
      expect(result.value[:updated_tutor_state].current_phase).to eq("guiding")
    end

    it "auto-transitions to guiding on success outcome" do
      conv = make_conversation(phase: "spotting_type", question_id: 3)
      result = described_class.call(
        conversation: conv,
        tool_calls: [ {
          name: "evaluate_spotting",
          args: {
            "task_type_identified" => "calcul",
            "sources_identified"   => [ "DT1" ],
            "missing_sources"      => [],
            "extra_sources"        => [],
            "feedback_message"     => "Bien.",
            "relaunch_prompt"      => "",
            "outcome"              => "success"
          }
        } ]
      )
      expect(result.ok?).to be true
      expect(result.value[:updated_tutor_state].current_phase).to eq("guiding")
    end
  end

  describe "unknown tool" do
    it "ignores unknown tool names gracefully" do
      conv = make_conversation
      result = described_class.call(
        conversation: conv,
        tool_calls: [ { name: "do_something_weird", args: {} } ]
      )
      expect(result.ok?).to be true
    end
  end

  describe "tool: transition — nouvelle TRANSITION_MATRIX (049)" do
    # These tests will FAIL until apply_tool_calls.rb is updated (TDD)

    it "allows greeting → enonce (nouveau flow sans reading)" do
      conv = make_conversation(phase: "greeting", question_id: 5)
      result = described_class.call(
        conversation: conv,
        tool_calls: [ { name: "transition", args: { "phase" => "enonce", "question_id" => 5 } } ]
      )
      expect(result.ok?).to be true
      expect(result.value[:updated_tutor_state].current_phase).to eq("enonce")
    end

    it "allows enonce → guiding (skip spotting pour qcm)" do
      conv = make_conversation(phase: "enonce", question_id: 5)
      result = described_class.call(
        conversation: conv,
        tool_calls: [ { name: "transition", args: { "phase" => "guiding", "question_id" => 5 } } ]
      )
      expect(result.ok?).to be true
      expect(result.value[:updated_tutor_state].current_phase).to eq("guiding")
    end

    it "allows enonce → spotting_type" do
      conv = make_conversation(phase: "enonce", question_id: 5)
      result = described_class.call(
        conversation: conv,
        tool_calls: [ { name: "transition", args: { "phase" => "spotting_type", "question_id" => 5 } } ]
      )
      expect(result.ok?).to be true
      expect(result.value[:updated_tutor_state].current_phase).to eq("spotting_type")
    end

    it "allows spotting_type → guiding (skip spotting_data si pas de DT/DR)" do
      conv = make_conversation(phase: "spotting_type", question_id: 5)
      result = described_class.call(
        conversation: conv,
        tool_calls: [ { name: "transition", args: { "phase" => "guiding", "question_id" => 5 } } ]
      )
      expect(result.ok?).to be true
      expect(result.value[:updated_tutor_state].current_phase).to eq("guiding")
    end

    it "allows spotting_type → spotting_data" do
      conv = make_conversation(phase: "spotting_type", question_id: 5)
      result = described_class.call(
        conversation: conv,
        tool_calls: [ { name: "transition", args: { "phase" => "spotting_data", "question_id" => 5 } } ]
      )
      expect(result.ok?).to be true
      expect(result.value[:updated_tutor_state].current_phase).to eq("spotting_data")
    end

    it "allows spotting_data → guiding" do
      conv = make_conversation(phase: "spotting_data", question_id: 5)
      result = described_class.call(
        conversation: conv,
        tool_calls: [ { name: "transition", args: { "phase" => "guiding", "question_id" => 5 } } ]
      )
      expect(result.ok?).to be true
      expect(result.value[:updated_tutor_state].current_phase).to eq("guiding")
    end

    it "allows guiding → enonce (passage question suivante)" do
      conv = make_conversation(phase: "guiding", question_id: 5)
      result = described_class.call(
        conversation: conv,
        tool_calls: [ { name: "transition", args: { "phase" => "enonce", "question_id" => 6 } } ]
      )
      expect(result.ok?).to be true
      expect(result.value[:updated_tutor_state].current_phase).to eq("enonce")
    end

    it "allows validating → ended (skip feedback)" do
      conv = make_conversation(phase: "validating", question_id: 5)
      result = described_class.call(
        conversation: conv,
        tool_calls: [ { name: "transition", args: { "phase" => "ended", "question_id" => 5 } } ]
      )
      expect(result.ok?).to be true
      expect(result.value[:updated_tutor_state].current_phase).to eq("ended")
    end

    it "silently ignores forbidden transition enonce → reading (old phase not in matrix)" do
      conv = make_conversation(phase: "enonce", question_id: 5)
      result = described_class.call(
        conversation: conv,
        tool_calls: [ { name: "transition", args: { "phase" => "reading", "question_id" => 5 } } ]
      )
      expect(result.ok?).to be true
      expect(result.value[:updated_tutor_state].current_phase).to eq("enonce")
    end

    it "persists QuestionState#phase when transitioning" do
      conv = make_conversation(phase: "enonce", question_id: 5)
      result = described_class.call(
        conversation: conv,
        tool_calls: [ { name: "transition", args: { "phase" => "spotting_type", "question_id" => 5 } } ]
      )
      expect(result.ok?).to be true
      updated = result.value[:updated_tutor_state]
      expect(updated.question_states["5"]&.phase).to eq("spotting_type")
    end
  end
end
