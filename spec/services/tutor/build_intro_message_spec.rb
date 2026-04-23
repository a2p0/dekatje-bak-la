require "rails_helper"

RSpec.describe Tutor::BuildIntroMessage do
  let(:user)         { create(:user) }
  let(:classroom)    { create(:classroom, owner: user) }
  let(:student)      { create(:student, classroom: classroom) }
  let(:subject)      { create(:subject, owner: user, status: :published) }
  let(:part)         { create(:part, subject: subject, number: 1, title: "Étude du système") }
  let(:question)     { create(:question, part: part, number: "1.1", points: 3, label: "Calculer la puissance.") }
  let(:conversation) { create(:conversation, student: student, subject: subject, lifecycle_state: "active") }

  describe ".call" do
    it "creates a Message with kind: :intro and role: :assistant" do
      described_class.call(question: question, conversation: conversation)
      msg = conversation.messages.reload.find_by(kind: :intro)
      expect(msg).to be_present
      expect(msg.role).to eq("assistant")
    end

    it "includes the question number in the intro message" do
      described_class.call(question: question, conversation: conversation)
      msg = conversation.messages.reload.find_by(kind: :intro)
      expect(msg.content).to include("1.1")
    end

    it "includes the points in the intro message" do
      described_class.call(question: question, conversation: conversation)
      msg = conversation.messages.reload.find_by(kind: :intro)
      expect(msg.content).to include("3")
    end

    it "returns ok result" do
      result = described_class.call(question: question, conversation: conversation)
      expect(result.ok?).to be true
    end

    it "does not create a second intro for the same question (idempotent)" do
      2.times { described_class.call(question: question, conversation: conversation) }
      expect(conversation.messages.where(kind: :intro).count).to eq(1)
    end

    it "creates a new intro for a different question (per-question scope)" do
      question2 = create(:question, part: part, number: "1.2", points: 2, label: "Calculer le rendement.")
      described_class.call(question: question, conversation: conversation)
      described_class.call(question: question2, conversation: conversation)
      expect(conversation.messages.where(kind: :intro).count).to eq(2)
    end

    it "sets intro_seen to true in TutorState for the question" do
      described_class.call(question: question, conversation: conversation)
      qs = conversation.reload.tutor_state.question_states[question.id.to_s]
      expect(qs&.intro_seen).to eq(true)
    end
  end
end
