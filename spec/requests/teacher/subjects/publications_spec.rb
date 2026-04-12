require "rails_helper"

RSpec.describe "Teacher::Subjects::Publications", type: :request do
  let(:user) { create(:user, confirmed_at: Time.current) }
  let(:exam_session) { create(:exam_session, owner: user) }
  let(:subject_obj) { create(:subject, :new_format, owner: user, exam_session: exam_session) }

  before { sign_in user }

  def with_validated_question(subj)
    part = create(:part, subject: subj, exam_session: nil, section_type: :specific, position: 0)
    create(:question, part: part, status: :validated)
    subj.reload
  end

  describe "POST /teacher/subjects/:subject_id/publication" do
    context "with a draft subject and at least one validated question" do
      before { with_validated_question(subject_obj) }

      it "publishes the subject" do
        post teacher_subject_publication_path(subject_obj)
        expect(subject_obj.reload.status).to eq("published")
      end

      it "redirects to the assign page with a notice" do
        post teacher_subject_publication_path(subject_obj)
        expect(response).to redirect_to(assign_teacher_subject_path(subject_obj))
        follow_redirect!
        expect(flash[:notice]).to match(/publié/i)
      end
    end

    context "with a pending_validation subject and at least one validated question" do
      before do
        with_validated_question(subject_obj)
        subject_obj.update!(status: :pending_validation)
      end

      it "publishes the subject" do
        post teacher_subject_publication_path(subject_obj)
        expect(subject_obj.reload.status).to eq("published")
      end
    end

    context "when the subject is already published" do
      before do
        with_validated_question(subject_obj)
        subject_obj.update!(status: :published)
      end

      it "redirects with an alert" do
        post teacher_subject_publication_path(subject_obj)
        expect(response).to redirect_to(teacher_subject_path(subject_obj))
        follow_redirect!
        expect(flash[:alert]).to match(/déjà publié/i)
      end

      it "does not change the status" do
        expect {
          post teacher_subject_publication_path(subject_obj)
        }.not_to change { subject_obj.reload.status }
      end
    end

    context "when no question is validated" do
      it "redirects with an alert" do
        post teacher_subject_publication_path(subject_obj)
        expect(response).to redirect_to(teacher_subject_path(subject_obj))
        follow_redirect!
        expect(flash[:alert]).to match(/question validée/i)
      end

      it "does not publish the subject" do
        post teacher_subject_publication_path(subject_obj)
        expect(subject_obj.reload.status).to eq("draft")
      end
    end

    context "when the teacher is not the owner" do
      let(:other_user) { create(:user, confirmed_at: Time.current) }
      let(:other_exam_session) { create(:exam_session, owner: other_user) }
      let(:other_subject) { create(:subject, :new_format, owner: other_user, exam_session: other_exam_session) }

      it "returns 404" do
        post teacher_subject_publication_path(other_subject)
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "DELETE /teacher/subjects/:subject_id/publication" do
    context "with a published subject" do
      before do
        with_validated_question(subject_obj)
        subject_obj.update!(status: :published)
      end

      it "unpublishes the subject back to draft" do
        delete teacher_subject_publication_path(subject_obj)
        expect(subject_obj.reload.status).to eq("draft")
      end

      it "redirects to the subject page with a notice" do
        delete teacher_subject_publication_path(subject_obj)
        expect(response).to redirect_to(teacher_subject_path(subject_obj))
        follow_redirect!
        expect(flash[:notice]).to match(/dépublié/i)
      end
    end

    context "when the subject is not published" do
      it "redirects with an alert" do
        delete teacher_subject_publication_path(subject_obj)
        expect(response).to redirect_to(teacher_subject_path(subject_obj))
        follow_redirect!
        expect(flash[:alert]).to match(/Seul un sujet publié/i)
      end

      it "does not change the status" do
        expect {
          delete teacher_subject_publication_path(subject_obj)
        }.not_to change { subject_obj.reload.status }
      end
    end

    context "when the teacher is not the owner" do
      let(:other_user) { create(:user, confirmed_at: Time.current) }
      let(:other_exam_session) { create(:exam_session, owner: other_user) }
      let(:other_subject) { create(:subject, :new_format, owner: other_user, exam_session: other_exam_session, status: :published) }

      it "returns 404" do
        delete teacher_subject_publication_path(other_subject)
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
