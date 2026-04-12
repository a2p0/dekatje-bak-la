require "rails_helper"

RSpec.describe "Teacher::Subjects::Assignments", type: :request do
  let(:user) { create(:user, confirmed_at: Time.current) }
  let(:exam_session) { create(:exam_session, owner: user) }
  let(:subject_obj) { create(:subject, :new_format, owner: user, exam_session: exam_session) }
  let(:classroom1) { create(:classroom, owner: user) }
  let(:classroom2) { create(:classroom, owner: user) }

  before { sign_in user }

  describe "GET /teacher/subjects/:subject_id/assignment/edit" do
    it "returns 200 and renders the edit form" do
      get edit_teacher_subject_assignment_path(subject_obj)
      expect(response).to have_http_status(:ok)
    end

    context "when the subject belongs to another teacher" do
      let(:other_exam_session) { create(:exam_session) }
      let(:other_subject) { create(:subject, :new_format, exam_session: other_exam_session) }

      it "returns 404" do
        get edit_teacher_subject_assignment_path(other_subject)
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "PATCH /teacher/subjects/:subject_id/assignment" do
    it "updates the classroom associations" do
      patch teacher_subject_assignment_path(subject_obj),
            params: { classroom_ids: [ classroom1.id, classroom2.id ] }
      expect(subject_obj.reload.classroom_ids).to contain_exactly(classroom1.id, classroom2.id)
    end

    it "clears classroom associations when no ids submitted" do
      subject_obj.classroom_ids = [ classroom1.id ]
      patch teacher_subject_assignment_path(subject_obj), params: {}
      expect(subject_obj.reload.classroom_ids).to be_empty
    end

    it "redirects to the subject page with a notice" do
      patch teacher_subject_assignment_path(subject_obj),
            params: { classroom_ids: [ classroom1.id ] }
      expect(response).to redirect_to(teacher_subject_path(subject_obj))
      follow_redirect!
      expect(flash[:notice]).to match(/Assignation mise à jour/i)
    end

    context "when the subject belongs to another teacher" do
      let(:other_exam_session) { create(:exam_session) }
      let(:other_subject) { create(:subject, :new_format, exam_session: other_exam_session) }

      it "returns 404" do
        patch teacher_subject_assignment_path(other_subject), params: { classroom_ids: [] }
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
