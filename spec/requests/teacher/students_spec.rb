require "rails_helper"

RSpec.describe "Teacher::Students", type: :request do
  let(:user) { create(:user, confirmed_at: Time.current) }
  let(:classroom) { create(:classroom, owner: user) }

  before { sign_in user }

  describe "GET /teacher/classrooms/:id/students/new" do
    it "returns 200" do
      get new_teacher_classroom_student_path(classroom)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /teacher/classrooms/:id/students" do
    it "creates a student and redirects" do
      expect {
        post teacher_classroom_students_path(classroom),
             params: { student: { first_name: "Jean", last_name: "Dupont" } }
      }.to change(Student, :count).by(1)
      expect(response).to redirect_to(teacher_classroom_path(classroom))
    end
  end

  describe "GET /teacher/classrooms/:id/students/bulk_new" do
    it "returns 200" do
      get bulk_new_teacher_classroom_students_path(classroom)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /teacher/classrooms/:id/students/bulk_create" do
    it "creates multiple students" do
      expect {
        post bulk_create_teacher_classroom_students_path(classroom),
             params: { students_list: "Jean Dupont\nMarie Martin" }
      }.to change(Student, :count).by(2)
    end
  end

  describe "POST reset_password" do
    let(:student) { create(:student, classroom: classroom) }

    it "resets password and redirects" do
      post reset_password_teacher_classroom_student_path(classroom, student)
      expect(response).to redirect_to(teacher_classroom_path(classroom))
    end
  end
end
