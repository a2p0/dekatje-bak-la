require "rails_helper"

RSpec.describe Conversation, type: :model do
  let(:classroom) { create(:classroom) }
  let(:student)   { create(:student, classroom: classroom) }
  let(:subject_record) { create(:subject, status: :published) }

  describe "associations" do
    it "belongs to student" do
      assoc = Conversation.reflect_on_association(:student)
      expect(assoc.macro).to eq(:belongs_to)
    end

    it "belongs to subject" do
      assoc = Conversation.reflect_on_association(:subject)
      expect(assoc.macro).to eq(:belongs_to)
    end

    it "has many messages with dependent destroy" do
      assoc = Conversation.reflect_on_association(:messages)
      expect(assoc.macro).to eq(:has_many)
      expect(assoc.options[:dependent]).to eq(:destroy)
    end
  end

  describe "AASM lifecycle" do
    subject(:conversation) do
      create(:conversation, student: student, subject: subject_record)
    end

    it "starts in the disabled state" do
      expect(conversation.lifecycle_state).to eq("disabled")
      expect(conversation).to be_disabled
    end

    context "when student has a personal API key" do
      before { student.update!(api_key: "sk-test-key", api_provider: :anthropic) }

      it "transitions to active via activate!" do
        expect { conversation.activate! }.to change {
          conversation.lifecycle_state
        }.from("disabled").to("active")
      end
    end

    context "when classroom has free mode enabled" do
      before { classroom.update!(tutor_free_mode_enabled: true) }

      it "allows activation without a student API key" do
        student.update!(api_key: nil)
        expect { conversation.activate! }.to change {
          conversation.lifecycle_state
        }.from("disabled").to("active")
      end
    end

    context "when student has no key and free mode is disabled" do
      before do
        student.update!(api_key: nil)
        classroom.update!(tutor_free_mode_enabled: false)
      end

      it "raises AASM::InvalidTransition on activate!" do
        expect { conversation.activate! }.to raise_error(AASM::InvalidTransition)
      end
    end

    context "when student has empty-string api_key and free mode is disabled" do
      before do
        student.update!(api_key: "")
        classroom.update!(tutor_free_mode_enabled: false)
      end

      it "raises AASM::InvalidTransition (empty string is not a key)" do
        expect { conversation.activate! }.to raise_error(AASM::InvalidTransition)
      end
    end

    context "when conversation is active" do
      before do
        student.update!(api_key: "sk-test-key", api_provider: :anthropic)
        conversation.activate!
      end

      it "transitions active → validating via request_validation!" do
        expect { conversation.request_validation! }.to change {
          conversation.lifecycle_state
        }.from("active").to("validating")
      end

      it "transitions validating → feedback via give_feedback!" do
        conversation.request_validation!
        expect { conversation.give_feedback! }.to change {
          conversation.lifecycle_state
        }.from("validating").to("feedback")
      end

      it "transitions feedback → active via resume!" do
        conversation.request_validation!
        conversation.give_feedback!
        expect { conversation.resume! }.to change {
          conversation.lifecycle_state
        }.from("feedback").to("active")
      end

      it "transitions active → done via finish!" do
        expect { conversation.finish! }.to change {
          conversation.lifecycle_state
        }.from("active").to("done")
      end

      it "transitions feedback → done via finish!" do
        conversation.request_validation!
        conversation.give_feedback!
        expect { conversation.finish! }.to change {
          conversation.lifecycle_state
        }.from("feedback").to("done")
      end
    end
  end

  describe "tutor_state attribute" do
    subject(:conversation) do
      create(:conversation, student: student, subject: subject_record)
    end

    it "returns a TutorState instance" do
      expect(conversation.tutor_state).to be_a(TutorState)
    end

    it "defaults to TutorState.default" do
      expect(conversation.tutor_state).to eq(TutorState.default)
    end

    it "defaults to TutorState.default after saving and reloading" do
      conversation.save!
      conversation.reload
      expect(conversation.tutor_state).to eq(TutorState.default)
    end

    it "persists a modified TutorState" do
      new_state = TutorState.new(
        current_phase:        "chat",
        current_question_id:  nil,
        concepts_mastered:    [ "énergie" ],
        concepts_to_revise:   [],
        discouragement_level: 0,
        question_states:      {}, welcome_sent: false)
      conversation.update!(tutor_state: new_state)
      conversation.reload
      expect(conversation.tutor_state.current_phase).to eq("chat")
      expect(conversation.tutor_state.concepts_mastered).to eq([ "énergie" ])
    end
  end

  describe "validations" do
    subject(:conversation) do
      create(:conversation, student: student, subject: subject_record)
    end

    it "is invalid if another conversation exists for the same (student, subject)" do
      conversation # create the first one
      duplicate = build(:conversation, student: student, subject: subject_record)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:student_id]).to include(/taken/i)
    end
  end
end