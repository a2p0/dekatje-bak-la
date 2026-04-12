require "rails_helper"

RSpec.describe "Teacher::Subjects::Extractions", type: :request do
  let(:user) { create(:user, confirmed_at: Time.current) }
  let(:exam_session) { create(:exam_session, owner: user) }
  let(:subject_obj) { create(:subject, :new_format, owner: user, exam_session: exam_session) }

  before { sign_in user }

  describe "POST /teacher/subjects/:subject_id/extraction" do
    context "when the extraction has failed" do
      let!(:extraction_job) { create(:extraction_job, subject: subject_obj, status: :failed, error_message: "Previous error") }

      it "resets the extraction job status and enqueues a new run" do
        expect {
          post teacher_subject_extraction_path(subject_obj)
        }.to have_enqueued_job(ExtractQuestionsJob).with(subject_obj.id)

        extraction_job.reload
        expect(extraction_job.status).to eq("processing")
        expect(extraction_job.error_message).to be_nil
      end

      it "redirects to the subject page with a notice" do
        post teacher_subject_extraction_path(subject_obj)
        expect(response).to redirect_to(teacher_subject_path(subject_obj))
        follow_redirect!
        expect(flash[:notice]).to match(/relancée/i)
      end
    end

    context "when the extraction is pending" do
      before { create(:extraction_job, subject: subject_obj, status: :pending) }

      it "refuses and redirects with an alert" do
        post teacher_subject_extraction_path(subject_obj)
        expect(response).to redirect_to(teacher_subject_path(subject_obj))
        follow_redirect!
        expect(flash[:alert]).to match(/échoué/i)
      end
    end

    context "when the extraction is processing" do
      before { create(:extraction_job, subject: subject_obj, status: :processing) }

      it "refuses and redirects with an alert" do
        post teacher_subject_extraction_path(subject_obj)
        expect(response).to redirect_to(teacher_subject_path(subject_obj))
        follow_redirect!
        expect(flash[:alert]).to match(/échoué/i)
      end
    end

    context "when the extraction is done" do
      before { create(:extraction_job, subject: subject_obj, status: :done) }

      it "refuses and redirects with an alert" do
        post teacher_subject_extraction_path(subject_obj)
        expect(response).to redirect_to(teacher_subject_path(subject_obj))
        follow_redirect!
        expect(flash[:alert]).to match(/échoué/i)
      end
    end

    context "when the subject has no extraction job" do
      it "refuses and redirects with an alert" do
        post teacher_subject_extraction_path(subject_obj)
        expect(response).to redirect_to(teacher_subject_path(subject_obj))
        follow_redirect!
        expect(flash[:alert]).to match(/échoué/i)
      end
    end

    context "when the subject belongs to another teacher" do
      let(:other_exam_session) { create(:exam_session) }
      let(:other_subject) { create(:subject, :new_format, exam_session: other_exam_session) }

      it "returns 404" do
        post teacher_subject_extraction_path(other_subject)
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
