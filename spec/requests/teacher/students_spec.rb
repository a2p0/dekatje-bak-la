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

  # Bulk import coverage moved to spec/requests/teacher/classrooms/student_imports_spec.rb
  # (refactored to RESTful Teacher::Classrooms::StudentImportsController#new/create)

  # Password reset coverage moved to spec/requests/teacher/students/password_resets_spec.rb
  # (refactored to RESTful Teacher::Students::PasswordResetsController#create)
end