require "rails_helper"

RSpec.describe "Student::Subjects::ScopeSelections", type: :request do
  let(:classroom) { create(:classroom) }
  let(:student) { create(:student, classroom: classroom) }
  let(:subject_obj) { create(:subject, status: :published) }

  before do
    create(:classroom_subject, classroom: classroom, subject: subject_obj)
    # Authenticate as student
    post student_session_path(access_code: classroom.access_code),
         params: { username: student.username, password: "password123" }
  end

  def create_student_session
    create(:student_session, student: student, subject: subject_obj)
  end

  describe "PATCH /:access_code/subjects/:subject_id/scope_selection" do
    context "with authenticated student" do
      it "updates part_filter to common_only and sets scope_selected true" do
        session_record = create_student_session

        patch student_subject_scope_selection_path(
          access_code: classroom.access_code,
          subject_id: subject_obj.id
        ), params: { part_filter: "common_only" }

        session_record.reload
        expect(session_record.part_filter).to eq("common_only")
        expect(session_record.scope_selected).to be true
        expect(response).to redirect_to(
          student_subject_path(access_code: classroom.access_code, id: subject_obj.id)
        )
      end

      it "updates part_filter to both (full) and sets scope_selected true" do
        session_record = create_student_session

        patch student_subject_scope_selection_path(
          access_code: classroom.access_code,
          subject_id: subject_obj.id
        ), params: { part_filter: "full" }

        session_record.reload
        expect(session_record.part_filter).to eq("full")
        expect(session_record.scope_selected).to be true
        expect(response).to redirect_to(
          student_subject_path(access_code: classroom.access_code, id: subject_obj.id)
        )
      end
    end

    context "without authenticated student" do
      before do
        # Clear the session established in the outer before block
        delete student_session_path(access_code: classroom.access_code)
      end

      it "redirects to student login" do
        patch student_subject_scope_selection_path(
          access_code: classroom.access_code,
          subject_id: subject_obj.id
        ), params: { part_filter: "common_only" }

        expect(response).to redirect_to(
          student_login_path(access_code: classroom.access_code)
        )
      end
    end
  end
end