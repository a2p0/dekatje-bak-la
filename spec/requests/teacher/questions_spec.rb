require "rails_helper"

RSpec.describe "Teacher::Questions", type: :request do
  let(:user) { create(:user, confirmed_at: Time.current) }
  let(:subject_obj) { create(:subject, owner: user) }
  let(:part) { create(:part, :specific, subject: subject_obj) }
  let(:question) { create(:question, part: part) }
  let(:answer) { create(:answer, question: question) }

  before { sign_in user }

  describe "PATCH /teacher/questions/:id" do
    it "updates the question" do
      patch teacher_question_path(question),
            params: { question: { label: "Nouveau label" } },
            headers: { "Accept" => "text/vnd.turbo-stream.html" }
      expect(question.reload.label).to eq("Nouveau label")
    end
  end

  describe "DELETE /teacher/questions/:id" do
    it "soft deletes the question" do
      delete teacher_question_path(question),
             headers: { "Accept" => "text/vnd.turbo-stream.html" }
      expect(question.reload.discarded_at).not_to be_nil
    end
  end

  # Validate/invalidate coverage moved to spec/requests/teacher/questions/validations_spec.rb
  # (refactored to RESTful Teacher::Questions::ValidationsController#create/destroy)
end
