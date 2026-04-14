require "rails_helper"

RSpec.xdescribe "Student::Subjects::TutorActivations", type: :request do
  let(:classroom) { create(:classroom) }
  let(:student) { create(:student, classroom: classroom) }
  let(:subject_obj) { create(:subject, status: :published) }

  before do
    create(:classroom_subject, classroom: classroom, subject: subject_obj)
  end

  def activation_path
    student_subject_tutor_activation_path(access_code: classroom.access_code, subject_id: subject_obj.id)
  end

  def login
    post student_session_path(access_code: classroom.access_code),
         params: { username: student.username, password: "password123" }
  end

  describe "POST /subjects/:subject_id/tutor_activation" do
    context "when authenticated" do
      before { login }

      context "when student has an autonomous session" do
        let!(:student_session) do
          create(:student_session, student: student, subject: subject_obj, mode: :autonomous)
        end

        it "switches mode to tutored and redirects to subject page with notice" do
          post activation_path

          student_session.reload
          expect(student_session.mode).to eq("tutored")
          expect(response).to redirect_to(
            student_subject_path(access_code: classroom.access_code, id: subject_obj.id)
          )
          expect(flash[:notice]).to include("Mode tuteur activé")
        end
      end

      context "when student already has a tutored session (idempotent)" do
        let!(:student_session) do
          create(:student_session, student: student, subject: subject_obj, mode: :tutored)
        end

        it "remains tutored without error and redirects" do
          post activation_path

          student_session.reload
          expect(student_session.mode).to eq("tutored")
          expect(response).to redirect_to(
            student_subject_path(access_code: classroom.access_code, id: subject_obj.id)
          )
        end
      end

      context "when no session exists yet" do
        it "creates a tutored session and redirects" do
          expect {
            post activation_path
          }.to change(StudentSession, :count).by(1)

          session_record = StudentSession.find_by(student: student, subject: subject_obj)
          expect(session_record.mode).to eq("tutored")
          expect(response).to redirect_to(
            student_subject_path(access_code: classroom.access_code, id: subject_obj.id)
          )
        end
      end
    end

    context "when not authenticated" do
      it "redirects to login" do
        post activation_path

        expect(response).to redirect_to(student_login_path(access_code: classroom.access_code))
      end
    end
  end
end
