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

  describe "AASM (062: 3-state machine)" do
    let(:student_with_key) { create(:student, :with_api_key) }
    let(:student_without_key) { create(:student) }

    let(:subject_record) { create(:subject) }

    it "starts as :disabled" do
      conv = create(:conversation, student: student_with_key, subject: subject_record)
      expect(conv).to be_disabled
    end

    it "transitions disabled → active when student has api_key" do
      conv = create(:conversation, student: student_with_key, subject: subject_record)
      expect(conv.may_activate?).to be(true)
      conv.activate!
      expect(conv).to be_active
    end

    it "guards activation when no api_key and no free mode" do
      conv = create(:conversation, student: student_without_key, subject: subject_record)
      expect { conv.activate! }.to raise_error(AASM::InvalidTransition)
    end

    it "transitions active → done via finish" do
      conv = create(:conversation, student: student_with_key, subject: subject_record).tap(&:activate!)
      conv.finish!
      expect(conv).to be_done
    end

    it "no longer exposes :validating or :feedback states" do
      conv = create(:conversation, student: student_with_key, subject: subject_record)
      expect(conv.aasm.states.map(&:name)).to match_array([ :disabled, :active, :done ])
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
