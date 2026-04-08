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
      other_es = create(:exam_session, title: "Sujet Non Assigne XYZ")
      other_subject = create(:subject, exam_session: other_es, status: :published)
      get student_root_path(access_code: classroom.access_code)
      expect(response.body).not_to include("Sujet Non Assigne XYZ")
    end

    it "does not show draft subjects" do
      draft_es = create(:exam_session, title: "Sujet Brouillon XYZ")
      draft = create(:subject, exam_session: draft_es, status: :draft)
      create(:classroom_subject, classroom: classroom, subject: draft)
      get student_root_path(access_code: classroom.access_code)
      expect(response.body).not_to include("Sujet Brouillon XYZ")
    end
  end

  describe "GET /subjects/:id (show)" do
    it "creates a student session and renders mise en situation" do
      part = create(:part, :specific, subject: subject_obj, position: 1)
      question = create(:question, part: part, position: 1)
      get student_subject_path(access_code: classroom.access_code, id: subject_obj.id)
      expect(response).to have_http_status(:ok)
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

  describe "PATCH /subjects/:id/complete_part/:part_id" do
    let(:part) { create(:part, :specific, subject: subject_obj, position: 1) }
    let!(:question) { create(:question, part: part, position: 1) }

    it "marks the part as completed and redirects to subject page" do
      get student_subject_path(access_code: classroom.access_code, id: subject_obj.id)

      patch student_complete_part_subject_path(
        access_code: classroom.access_code,
        id: subject_obj.id,
        part_id: part.id
      )

      expect(response).to redirect_to(student_subject_path(access_code: classroom.access_code, id: subject_obj.id))
      session_record = StudentSession.find_by(student: student, subject: subject_obj)
      expect(session_record.part_completed?(part.id)).to be true
    end
  end

  describe "PATCH /subjects/:id/complete" do
    let(:part) { create(:part, :specific, subject: subject_obj, position: 1) }
    let!(:question) { create(:question, part: part, position: 1) }

    it "marks the subject as completed and redirects to subject page" do
      get student_subject_path(access_code: classroom.access_code, id: subject_obj.id)

      patch student_complete_subject_path(
        access_code: classroom.access_code,
        id: subject_obj.id
      )

      expect(response).to redirect_to(student_subject_path(access_code: classroom.access_code, id: subject_obj.id))
      session_record = StudentSession.find_by(student: student, subject: subject_obj)
      expect(session_record.subject_completed?).to be true
    end
  end
end
