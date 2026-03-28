require "rails_helper"

RSpec.describe StudentSession, type: :model do
  describe "associations" do
    it "belongs to student" do
      ss = build(:student_session)
      expect(ss.student).to be_a(Student)
    end

    it "belongs to subject" do
      ss = build(:student_session)
      expect(ss.subject).to be_a(Subject)
    end
  end

  describe "uniqueness" do
    it "prevents duplicate student-subject pairs" do
      student = create(:student)
      subject = create(:subject)
      create(:student_session, student: student, subject: subject)
      duplicate = build(:student_session, student: student, subject: subject)
      expect(duplicate).not_to be_valid
    end
  end

  describe "#mark_seen!" do
    it "sets seen to true for question" do
      ss = create(:student_session)
      question = create(:question)
      ss.mark_seen!(question.id)
      expect(ss.reload.progression[question.id.to_s]["seen"]).to be true
    end
  end

  describe "#mark_answered!" do
    it "sets answered to true for question" do
      ss = create(:student_session)
      question = create(:question)
      ss.mark_answered!(question.id)
      expect(ss.reload.progression[question.id.to_s]["answered"]).to be true
    end
  end

  describe "#answered?" do
    it "returns false for unseen question" do
      ss = create(:student_session)
      expect(ss.answered?(999)).to be false
    end

    it "returns true for answered question" do
      ss = create(:student_session, progression: { "42" => { "answered" => true } })
      expect(ss.answered?(42)).to be true
    end
  end

  describe "#first_undone_question" do
    it "returns first unanswered question in part" do
      ss = create(:student_session)
      part = create(:part, subject: ss.subject)
      q1 = create(:question, part: part, position: 1)
      q2 = create(:question, part: part, number: "1.2", position: 2)
      ss.update!(progression: { q1.id.to_s => { "answered" => true } })
      expect(ss.first_undone_question(part)).to eq(q2)
    end

    it "returns first question when all done" do
      ss = create(:student_session)
      part = create(:part, subject: ss.subject)
      q1 = create(:question, part: part, position: 1)
      ss.update!(progression: { q1.id.to_s => { "answered" => true } })
      expect(ss.first_undone_question(part)).to eq(q1)
    end
  end
end
