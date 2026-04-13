require "rails_helper"

RSpec.describe "Student::Subjects::Completions", type: :request do
  let(:classroom) { create(:classroom) }
  let(:student) { create(:student, classroom: classroom) }
  let(:subject_obj) { create(:subject, status: :published) }
  let(:part) { create(:part, :specific, subject: subject_obj, position: 1) }
  let!(:question) { create(:question, part: part, position: 1) }

  before do
    create(:classroom_subject, classroom: classroom, subject: subject_obj)
  end

  def completion_path
    student_subject_completion_path(access_code: classroom.access_code, subject_id: subject_obj.id)
  end

  def login
    post student_session_path(access_code: classroom.access_code),
         params: { username: student.username, password: "password123" }
  end

  describe "POST /subjects/:subject_id/completion" do
    context "when authenticated" do
      before do
        login
        # Ensure session_record exists (subject#show creates it)
        create(:student_session, student: student, subject: subject_obj, mode: :autonomous)
      end

      it "marks the subject as completed and redirects with completed=true" do
        post completion_path

        expect(response).to redirect_to(
          student_subject_path(access_code: classroom.access_code, id: subject_obj.id, completed: true)
        )
        session_record = StudentSession.find_by(student: student, subject: subject_obj)
        expect(session_record.subject_completed?).to be true
      end
    end

    context "when not authenticated" do
      it "redirects to login" do
        post completion_path

        expect(response).to redirect_to(student_login_path(access_code: classroom.access_code))
      end
    end
  end
end
