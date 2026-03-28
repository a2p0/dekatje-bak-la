require "rails_helper"

RSpec.describe "Teacher::Questions", type: :request do
  let(:user) { create(:user, confirmed_at: Time.current) }
  let(:subject_obj) { create(:subject, owner: user) }
  let(:part) { create(:part, subject: subject_obj) }
  let(:question) { create(:question, part: part) }
  let(:answer) { create(:answer, question: question) }

  before { sign_in user }

  describe "PATCH /teacher/subjects/:subject_id/parts/:part_id/questions/:id" do
    it "updates the question" do
      patch teacher_subject_part_question_path(subject_obj, part, question),
            params: { question: { label: "Nouveau label" } },
            headers: { "Accept" => "text/vnd.turbo-stream.html" }
      expect(question.reload.label).to eq("Nouveau label")
    end
  end

  describe "DELETE /teacher/subjects/:subject_id/parts/:part_id/questions/:id" do
    it "soft deletes the question" do
      delete teacher_subject_part_question_path(subject_obj, part, question),
             headers: { "Accept" => "text/vnd.turbo-stream.html" }
      expect(question.reload.discarded_at).not_to be_nil
    end
  end

  describe "PATCH validate" do
    it "validates the question" do
      patch validate_teacher_subject_part_question_path(subject_obj, part, question),
            headers: { "Accept" => "text/vnd.turbo-stream.html" }
      expect(question.reload.status).to eq("validated")
    end
  end

  describe "PATCH invalidate" do
    let(:question) { create(:question, part: part, status: :validated) }

    it "invalidates the question" do
      patch invalidate_teacher_subject_part_question_path(subject_obj, part, question),
            headers: { "Accept" => "text/vnd.turbo-stream.html" }
      expect(question.reload.status).to eq("draft")
    end
  end
end
