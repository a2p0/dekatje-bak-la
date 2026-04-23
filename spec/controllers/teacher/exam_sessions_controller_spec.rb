require "rails_helper"

RSpec.describe Teacher::ExamSessionsController, type: :request do
  let(:teacher) { create(:user, :confirmed) }
  let(:exam_session) { create(:exam_session, owner: teacher) }

  before { sign_in teacher }

  describe "DELETE #destroy" do
    context "when exam_session has no subjects" do
      let!(:common_part) do
        create(:part, exam_session: exam_session, subject: nil,
               number: 1, title: "Commune", section_type: :common, position: 0)
      end

      it "destroys the exam_session" do
        delete teacher_exam_session_path(exam_session)
        expect(ExamSession.find_by(id: exam_session.id)).to be_nil
      end

      it "destroys associated common parts" do
        delete teacher_exam_session_path(exam_session)
        expect(Part.find_by(id: common_part.id)).to be_nil
      end

      it "redirects with success notice" do
        delete teacher_exam_session_path(exam_session)
        expect(response).to redirect_to(teacher_subjects_path)
        follow_redirect!
        expect(response.body).to include("supprimée")
      end
    end

    context "when exam_session still has subjects" do
      let!(:subject_obj) { create(:subject, :new_format, exam_session: exam_session, owner: teacher) }

      it "does not destroy the exam_session" do
        delete teacher_exam_session_path(exam_session)
        expect(ExamSession.find_by(id: exam_session.id)).to be_present
      end

      it "redirects with error alert" do
        delete teacher_exam_session_path(exam_session)
        expect(response).to redirect_to(teacher_subjects_path)
        follow_redirect!
        expect(response.body).to include("Impossible de supprimer")
      end
    end

    it "cannot destroy another teacher's exam_session" do
      other_teacher = create(:user, :confirmed)
      other_session = create(:exam_session, owner: other_teacher)

      delete teacher_exam_session_path(other_session)
      expect(response).to have_http_status(:not_found)
    end
  end
end
