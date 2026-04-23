require "rails_helper"

RSpec.describe Tutor::InjectDataHints do
  let(:user)         { create(:user) }
  let(:classroom)    { create(:classroom, owner: user) }
  let(:student)      { create(:student, classroom: classroom) }
  let(:exam_subject) { create(:subject, owner: user, status: :published) }
  let(:part)         { create(:part, subject: exam_subject) }
  let(:question)     { create(:question, part: part) }
  let!(:answer) do
    create(:answer, question: question,
      correction_text: "Car = 56,73 l",
      data_hints: [
        { "source" => "DT1", "location" => "tableau Consommation moyenne" },
        { "source" => "mise_en_situation", "location" => "distance 186 km" }
      ])
  end
  let(:conversation) do
    create(:conversation, student: student, subject: exam_subject,
           lifecycle_state: "active")
  end

  shared_examples "injects data_hints" do |outcome_value|
    it "creates a system Message with the rendered data_hints" do
      described_class.call(
        conversation: conversation,
        question:     question,
        outcome:      outcome_value
      )
      system_msg = conversation.messages.reload.find { |m| m.role == "system" }
      expect(system_msg).to be_present
      expect(system_msg.content).to include("DT1")
      expect(system_msg.content).to include("tableau Consommation moyenne")
      expect(system_msg.content).to include("mise_en_situation")
    end

    it "broadcasts to the conversation channel with type data_hints" do
      expect(ActionCable.server).to receive(:broadcast).with(
        "conversation_#{conversation.id}",
        hash_including(type: "data_hints")
      )
      described_class.call(
        conversation: conversation,
        question:     question,
        outcome:      outcome_value
      )
    end

    it "returns ok" do
      result = described_class.call(
        conversation: conversation,
        question:     question,
        outcome:      outcome_value
      )
      expect(result.ok?).to be true
    end
  end

  context "with outcome 'success'" do
    include_examples "injects data_hints", "success"
  end

  context "with outcome 'forced_reveal'" do
    include_examples "injects data_hints", "forced_reveal"
  end

  context "with outcome 'relaunch' (non-terminal)" do
    it "does not create any message" do
      expect {
        described_class.call(
          conversation: conversation,
          question:     question,
          outcome:      "relaunch"
        )
      }.not_to change { conversation.messages.count }
    end

    it "returns ok without side effects" do
      result = described_class.call(
        conversation: conversation,
        question:     question,
        outcome:      "relaunch"
      )
      expect(result.ok?).to be true
    end
  end

  context "when answer has no data_hints" do
    before { answer.update!(data_hints: []) }

    it "does not create any message even on success outcome" do
      expect {
        described_class.call(
          conversation: conversation,
          question:     question,
          outcome:      "success"
        )
      }.not_to change { conversation.messages.count }
    end
  end
end
