require "rails_helper"

RSpec.describe "Student::Questions::Corrections", type: :request do
  let(:classroom) { create(:classroom) }
  let(:student) { create(:student, classroom: classroom) }
  let(:subject_obj) { create(:subject, status: :published) }
  let(:part) { create(:part, subject: subject_obj, position: 1) }
  let(:question) { create(:question, part: part, position: 1) }
  let!(:answer) { create(:answer, question: question) }

  before do
    create(:classroom_subject, classroom: classroom, subject: subject_obj)
  end

  def sign_in_student
    post student_session_path(access_code: classroom.access_code),
         params: { username: student.username, password: "password123" }
  end

  def post_correction
    post student_subject_question_correction_path(
      access_code: classroom.access_code,
      subject_id: subject_obj.id,
      question_id: question.id
    ), headers: { "Accept" => "text/vnd.turbo-stream.html" }
  end

  describe "POST /subjects/:subject_id/questions/:question_id/correction" do
    context "when authenticated" do
      before do
        sign_in_student
        # Visiting the question page creates the session record (as show does find_or_create_by!)
        get student_question_path(
          access_code: classroom.access_code,
          subject_id: subject_obj.id,
          id: question.id
        )
      end

      it "marks the question as answered" do
        post_correction
        ss = StudentSession.find_by(student: student, subject: subject_obj)
        expect(ss.progression[question.id.to_s]["answered"]).to be true
      end

      it "returns a Turbo Stream response with the correction partial" do
        post_correction
        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include("text/vnd.turbo-stream.html")
        expect(response.body).to include("question_#{question.id}_correction")
      end
    end

    context "when the question does not belong to the subject" do
      before do
        sign_in_student
        get student_question_path(
          access_code: classroom.access_code,
          subject_id: subject_obj.id,
          id: question.id
        )
      end

      it "redirects to student root" do
        other_subject = create(:subject, status: :published)
        create(:classroom_subject, classroom: classroom, subject: other_subject)
        other_part = create(:part, subject: other_subject)
        other_question = create(:question, part: other_part)

        post student_subject_question_correction_path(
          access_code: classroom.access_code,
          subject_id: subject_obj.id,
          question_id: other_question.id
        ), headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(response).to redirect_to(student_root_path(access_code: classroom.access_code))
      end
    end

    context "when not authenticated" do
      it "redirects to login" do
        post_correction
        expect(response).to redirect_to(student_login_path(access_code: classroom.access_code))
      end
    end
  end
end