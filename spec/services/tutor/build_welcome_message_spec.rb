require "rails_helper"

RSpec.describe Tutor::BuildWelcomeMessage do
  let(:user)         { create(:user) }
  let(:classroom)    { create(:classroom, owner: user) }
  let(:student)      { create(:student, classroom: classroom, api_key: "sk-test", api_provider: :anthropic, use_personal_key: true) }
  let(:exam_session) { create(:exam_session, title: "CIME 2024", owner: user) }
  let(:subject)      { create(:subject, owner: user, status: :published, exam_session: exam_session) }
  let!(:cs)          { create(:classroom_subject, classroom: classroom, subject: subject) }
  let(:part)         { create(:part, subject: subject) }
  let!(:q1)          { create(:question, part: part, status: :validated) }
  let!(:q2)          { create(:question, part: part, status: :validated) }
  let(:conversation) { create(:conversation, student: student, subject: subject, lifecycle_state: "active") }
  let(:api_key_data) { { api_key: "sk-test", provider: "anthropic", model: "claude-haiku-4-5" } }

  describe ".should_greet? (T018 — US3)" do
    def conv_with_state(welcome_sent:, last_activity_at:)
      state = TutorState.new(
        current_phase: "idle", current_question_id: nil,
        concepts_mastered: [], concepts_to_revise: [],
        discouragement_level: 0, question_states: {},
        welcome_sent: welcome_sent, last_activity_at: last_activity_at
      )
      create(:conversation, student: student, subject: subject,
             lifecycle_state: "active", tutor_state: state)
    end

    it "returns true when welcome_sent is false" do
      conv = conv_with_state(welcome_sent: false, last_activity_at: nil)
      expect(described_class.should_greet?(conversation: conv, last_activity_at: nil)).to be true
    end

    it "returns false when welcome_sent and last_activity_at is recent (< 12h)" do
      recent = 1.hour.ago
      conv = conv_with_state(welcome_sent: true, last_activity_at: recent)
      expect(described_class.should_greet?(conversation: conv, last_activity_at: recent)).to be false
    end

    it "returns true when welcome_sent but last_activity_at is stale (> 12h)" do
      stale = 13.hours.ago
      conv = conv_with_state(welcome_sent: true, last_activity_at: stale)
      expect(described_class.should_greet?(conversation: conv, last_activity_at: stale)).to be true
    end

    it "returns false when welcome_sent and last_activity_at is nil (welcome just sent, no messages yet)" do
      conv = conv_with_state(welcome_sent: true, last_activity_at: nil)
      expect(described_class.should_greet?(conversation: conv, last_activity_at: nil)).to be false
    end
  end

  describe ".call" do
    context "when LLM succeeds" do
      before do
        FakeRubyLlm.setup_stub(content: "Tu peux le faire !", tool_calls: [])
      end

      it "returns ok result" do
        result = described_class.call(subject: subject, conversation: conversation, api_key_data: api_key_data)
        expect(result.ok?).to be true
      end

      it "persists a welcome message containing the subject title" do
        described_class.call(subject: subject, conversation: conversation, api_key_data: api_key_data)
        msg = conversation.messages.reload.find_by(kind: :welcome)
        expect(msg).to be_present
        expect(msg.content).to include("CIME 2024")
      end

      it "persists a welcome message containing the question count" do
        described_class.call(subject: subject, conversation: conversation, api_key_data: api_key_data)
        msg = conversation.messages.reload.find_by(kind: :welcome)
        expect(msg.content).to include("2")
      end

      it "persists the message with kind: :welcome and role: :assistant" do
        described_class.call(subject: subject, conversation: conversation, api_key_data: api_key_data)
        msg = conversation.messages.reload.find_by(kind: :welcome)
        expect(msg.role).to eq("assistant")
        expect(msg.kind).to eq("welcome")
      end

      it "updates welcome_sent to true in TutorState" do
        described_class.call(subject: subject, conversation: conversation, api_key_data: api_key_data)
        expect(conversation.reload.tutor_state.welcome_sent).to eq(true)
      end
    end

    context "when LLM fails" do
      before do
        FakeRubyLlm.setup_stub(raise_error: StandardError.new("timeout"))
      end

      it "does not raise an exception" do
        expect {
          described_class.call(subject: subject, conversation: conversation, api_key_data: api_key_data)
        }.not_to raise_error
      end

      it "persists a welcome message using the static fallback" do
        described_class.call(subject: subject, conversation: conversation, api_key_data: api_key_data)
        msg = conversation.messages.reload.find_by(kind: :welcome)
        expect(msg).to be_present
        expect(msg.content).to include("Lance-toi quand tu es prêt")
      end

      it "still sets welcome_sent to true" do
        described_class.call(subject: subject, conversation: conversation, api_key_data: api_key_data)
        expect(conversation.reload.tutor_state.welcome_sent).to eq(true)
      end
    end
  end
end
