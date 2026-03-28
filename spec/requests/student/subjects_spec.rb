require "rails_helper"

RSpec.describe "Student::Subjects", type: :request do
  let(:classroom) { create(:classroom) }
  let(:student) { create(:student, classroom: classroom) }
  let(:subject_obj) { create(:subject, status: :published) }

  before do
    create(:classroom_subject, classroom: classroom, subject: subject_obj)
    post student_session_path(access_code: classroom.access_code),
         params: { username: student.username, password: "password123" }
  end

  describe "GET /subjects (index)" do
    it "returns 200 and shows assigned subjects" do
      get student_root_path(access_code: classroom.access_code)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(subject_obj.title)
    end

    it "does not show unassigned subjects" do
      other_subject = create(:subject, status: :published)
      get student_root_path(access_code: classroom.access_code)
      expect(response.body).not_to include(other_subject.title)
    end

    it "does not show draft subjects" do
      draft = create(:subject, status: :draft)
      create(:classroom_subject, classroom: classroom, subject: draft)
      get student_root_path(access_code: classroom.access_code)
      expect(response.body).not_to include(draft.title)
    end
  end

  describe "GET /subjects/:id (show)" do
    it "creates a student session and redirects to first question" do
      part = create(:part, subject: subject_obj, position: 1)
      question = create(:question, part: part, position: 1)
      get student_subject_path(access_code: classroom.access_code, id: subject_obj.id)
      expect(response).to redirect_to(
        student_question_path(access_code: classroom.access_code, subject_id: subject_obj.id, id: question.id)
      )
      expect(StudentSession.where(student: student, subject: subject_obj).count).to eq(1)
    end

    it "redirects with alert for subject without parts" do
      get student_subject_path(access_code: classroom.access_code, id: subject_obj.id)
      expect(response).to redirect_to(student_root_path(access_code: classroom.access_code))
      expect(flash[:alert]).to include("pas encore de questions")
    end

    it "redirects for unassigned subject" do
      other = create(:subject, status: :published)
      get student_subject_path(access_code: classroom.access_code, id: other.id)
      expect(response).to redirect_to(student_root_path(access_code: classroom.access_code))
    end
  end
end
