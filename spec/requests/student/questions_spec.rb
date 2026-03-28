require "rails_helper"

RSpec.describe "Student::Questions", type: :request do
  let(:classroom) { create(:classroom) }
  let(:student) { create(:student, classroom: classroom) }
  let(:subject_obj) { create(:subject, status: :published) }
  let(:part) { create(:part, subject: subject_obj, position: 1) }
  let(:question) { create(:question, part: part, position: 1) }
  let!(:answer) { create(:answer, question: question) }

  before do
    create(:classroom_subject, classroom: classroom, subject: subject_obj)
    post student_session_path(access_code: classroom.access_code),
         params: { username: student.username, password: "password123" }
  end

  describe "GET /subjects/:subject_id/questions/:id (show)" do
    it "returns 200" do
      get student_question_path(access_code: classroom.access_code, subject_id: subject_obj.id, id: question.id)
      expect(response).to have_http_status(:ok)
    end

    it "marks question as seen" do
      get student_question_path(access_code: classroom.access_code, subject_id: subject_obj.id, id: question.id)
      ss = StudentSession.find_by(student: student, subject: subject_obj)
      expect(ss.progression[question.id.to_s]["seen"]).to be true
    end

    it "redirects for question from unassigned subject" do
      other_subject = create(:subject, status: :published)
      other_part = create(:part, subject: other_subject)
      other_q = create(:question, part: other_part)
      get student_question_path(access_code: classroom.access_code, subject_id: other_subject.id, id: other_q.id)
      expect(response).to redirect_to(student_root_path(access_code: classroom.access_code))
    end
  end

  describe "PATCH /subjects/:subject_id/questions/:id/reveal" do
    it "marks question as answered" do
      patch student_reveal_question_path(
        access_code: classroom.access_code, subject_id: subject_obj.id, id: question.id
      ), headers: { "Accept" => "text/vnd.turbo-stream.html" }
      ss = StudentSession.find_by(student: student, subject: subject_obj)
      expect(ss.progression[question.id.to_s]["answered"]).to be true
    end
  end
end
