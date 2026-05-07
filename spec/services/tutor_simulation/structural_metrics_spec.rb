require "rails_helper"

RSpec.describe TutorSimulation::StructuralMetrics do
  let(:student) { create(:student) }
  let(:subject_record) { create(:subject) }
  let(:question) { create(:question, part: create(:part, subject: subject_record), answer_type: "calcul") }
  let(:conversation) { create(:conversation, student: student, subject: subject_record) }

  def append(type, **payload)
    Tutor::RecordEvent.call(conversation: conversation, question_id: question.id,
                            type: type, source: "code", **payload)
    conversation.reload
  end

  describe "resolution_rate" do
    it "is 1.0 when student_attempt verdict=correct precedes viewed_correction" do
      append("student_attempt", verdict: "correct", content: "56,73")

      metrics = described_class.compute(conversation: conversation, question_ids: [ question.id ])
      expect(metrics[:resolution_rate]).to eq(1.0)
    end

    it "is 0.0 when student_attempt correct comes after viewed_correction" do
      append("viewed_correction")
      append("student_attempt", verdict: "correct", content: "56,73")

      metrics = described_class.compute(conversation: conversation, question_ids: [ question.id ])
      expect(metrics[:resolution_rate]).to eq(0.0)
    end

    it "is 0.0 when no correct attempt exists" do
      append("student_attempt", verdict: "incorrect", content: "5673")
      metrics = described_class.compute(conversation: conversation, question_ids: [ question.id ])
      expect(metrics[:resolution_rate]).to eq(0.0)
    end
  end

  describe "cap_violations" do
    it "counts cap_violation events" do
      append("cap_violation")
      append("cap_violation")
      metrics = described_class.compute(conversation: conversation, question_ids: [ question.id ])
      expect(metrics[:cap_violations]).to eq(2)
    end
  end

  describe "proactive_help_rate" do
    it "is 0 when all tutor_gave events follow a chip_click student_attempt" do
      append("student_attempt", verdict: "incorrect")
      append("tutor_gave", what: "formule")
      metrics = described_class.compute(conversation: conversation, question_ids: [ question.id ])
      expect(metrics[:proactive_help_rate]).to eq(0.0)
    end

    it "is 1.0 when tutor_gave appears with no preceding student_attempt" do
      append("tutor_gave", what: "formule")
      metrics = described_class.compute(conversation: conversation, question_ids: [ question.id ])
      expect(metrics[:proactive_help_rate]).to eq(1.0)
    end
  end

  describe "mean_help_steps_before_resolution" do
    it "averages tutor_gave count up to first correct attempt" do
      append("tutor_gave", what: "formule")
      append("tutor_gave", what: "valeur")
      append("student_attempt", verdict: "correct")
      metrics = described_class.compute(conversation: conversation, question_ids: [ question.id ])
      expect(metrics[:mean_help_steps_before_resolution]).to eq(2.0)
    end
  end

  describe "correct_attempts_after_help_rate" do
    it "is 1.0 when correct attempt follows a tutor_gave" do
      append("tutor_gave", what: "formule")
      append("student_attempt", verdict: "correct")
      metrics = described_class.compute(conversation: conversation, question_ids: [ question.id ])
      expect(metrics[:correct_attempts_after_help_rate]).to eq(1.0)
    end
  end
end
