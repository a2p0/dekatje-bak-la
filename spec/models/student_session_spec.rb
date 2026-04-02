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

  describe "tutor_state helpers" do
    let(:ss) { create(:student_session, mode: :tutored) }
    let(:question_id) { 123 }

    describe "#question_step" do
      it "returns nil when no state exists for question" do
        expect(ss.question_step(question_id)).to be_nil
      end

      it "returns the step string when set" do
        ss.update!(tutor_state: { "question_states" => { question_id.to_s => { "step" => "spotting" } } })
        expect(ss.question_step(question_id)).to eq("spotting")
      end
    end

    describe "#set_question_step!" do
      it "persists the step for the question" do
        ss.set_question_step!(question_id, "spotting")
        expect(ss.reload.question_step(question_id)).to eq("spotting")
      end

      it "does not overwrite other question states" do
        ss.update!(tutor_state: { "question_states" => { "99" => { "step" => "feedback" } } })
        ss.set_question_step!(question_id, "spotting")
        expect(ss.reload.question_step(99)).to eq("feedback")
        expect(ss.reload.question_step(question_id)).to eq("spotting")
      end
    end

    describe "#store_spotting!" do
      it "persists spotting data for the question" do
        data = { "task_type_answer" => "calculation" }
        ss.store_spotting!(question_id, data)
        expect(ss.reload.spotting_data(question_id)).to eq(data)
      end

      it "does not overwrite the step when storing spotting" do
        ss.set_question_step!(question_id, "spotting")
        ss.store_spotting!(question_id, { "task_type_answer" => "calculation" })
        expect(ss.reload.question_step(question_id)).to eq("spotting")
      end
    end

    describe "#spotting_data" do
      it "returns nil when no spotting stored" do
        expect(ss.spotting_data(question_id)).to be_nil
      end

      it "returns the stored hash" do
        data = { "task_type_answer" => "text" }
        ss.update!(tutor_state: { "question_states" => { question_id.to_s => { "spotting" => data } } })
        expect(ss.spotting_data(question_id)).to eq(data)
      end
    end

    describe "#spotting_completed?" do
      it "returns false when no step set" do
        expect(ss.spotting_completed?(question_id)).to be false
      end

      it "returns true when step is feedback" do
        ss.set_question_step!(question_id, "feedback")
        expect(ss.spotting_completed?(question_id)).to be true
      end

      it "returns true when step is skipped" do
        ss.set_question_step!(question_id, "skipped")
        expect(ss.spotting_completed?(question_id)).to be true
      end

      it "returns false when step is spotting" do
        ss.set_question_step!(question_id, "spotting")
        expect(ss.spotting_completed?(question_id)).to be false
      end
    end

    describe "#tutored_active?" do
      it "returns false for autonomous session" do
        ss_auto = create(:student_session, mode: :autonomous)
        expect(ss_auto.tutored_active?).to be false
      end

      it "returns false for tutored session with no question_states" do
        expect(ss.tutored_active?).to be false
      end

      it "returns false for tutored session with empty question_states" do
        ss.update!(tutor_state: { "question_states" => {} })
        expect(ss.tutored_active?).to be false
      end

      it "returns true for tutored session with at least one question state" do
        ss.update!(tutor_state: { "question_states" => { "42" => { "step" => "spotting" } } })
        expect(ss.tutored_active?).to be true
      end
    end
  end
end
