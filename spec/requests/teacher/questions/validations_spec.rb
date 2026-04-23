require "rails_helper"

RSpec.describe "Teacher::Questions::Validations", type: :request do
  let(:user) { create(:user, confirmed_at: Time.current) }
  let(:subject_obj) { create(:subject, owner: user) }
  let(:part) { create(:part, :specific, subject: subject_obj) }
  let(:question) { create(:question, part: part, status: :draft) }

  before { sign_in user }

  describe "POST /teacher/questions/:question_id/validation" do
    context "with a draft question" do
      it "transitions status to validated" do
        post teacher_question_validation_path(question)
        expect(question.reload.status).to eq("validated")
      end

      it "responds with a Turbo Stream replace" do
        post teacher_question_validation_path(question), headers: { "Accept" => "text/vnd.turbo-stream.html" }
        expect(response.content_type).to include("text/vnd.turbo-stream.html")
        expect(response.body).to include("turbo-stream")
      end
    end

    context "when the question is already validated" do
      before { question.update!(status: :validated) }

      it "responds with a Turbo Stream flash alert" do
        post teacher_question_validation_path(question), headers: { "Accept" => "text/vnd.turbo-stream.html" }
        expect(response.body).to include("déjà validée")
      end

      it "does not change the status" do
        expect {
          post teacher_question_validation_path(question)
        }.not_to change { question.reload.status }
      end
    end

    context "when the question belongs to another teacher" do
      let(:other_subject) { create(:subject) }
      let(:other_part) { create(:part, :specific, subject: other_subject) }
      let(:other_question) { create(:question, part: other_part, status: :draft) }

      it "returns 404" do
        post teacher_question_validation_path(other_question)
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "DELETE /teacher/questions/:question_id/validation" do
    context "with a validated question" do
      before { question.update!(status: :validated) }

      it "transitions status to draft" do
        delete teacher_question_validation_path(question)
        expect(question.reload.status).to eq("draft")
      end
    end

    context "when the question is already draft" do
      it "responds with a Turbo Stream flash alert" do
        delete teacher_question_validation_path(question), headers: { "Accept" => "text/vnd.turbo-stream.html" }
        expect(response.body).to include("brouillon")
      end

      it "does not change the status" do
        expect {
          delete teacher_question_validation_path(question)
        }.not_to change { question.reload.status }
      end
    end
  end
end
