require "rails_helper"

RSpec.describe "Teacher::Students::PasswordResets", type: :request do
  let(:user) { create(:user, confirmed_at: Time.current) }
  let(:classroom) { create(:classroom, owner: user) }
  let(:student) { create(:student, classroom: classroom) }

  before { sign_in user }

  describe "POST /teacher/students/:student_id/password_reset" do
    it "resets the password" do
      original_password_digest = student.password_digest
      post teacher_student_password_reset_path(student)
      expect(student.reload.password_digest).not_to eq(original_password_digest)
    end

    it "stores generated credentials in the session" do
      post teacher_student_password_reset_path(student)
      expect(session[:generated_credentials]).to be_present
      expect(session[:generated_credentials].first["username"]).to eq(student.username)
      expect(session[:generated_credentials].first["password"]).to be_present
    end

    it "redirects to the classroom page with a notice" do
      post teacher_student_password_reset_path(student)
      expect(response).to redirect_to(teacher_classroom_path(classroom))
      follow_redirect!
      expect(flash[:notice]).to match(/réinitialisé/i)
    end

    context "when the classroom belongs to another teacher" do
      let(:other_classroom) { create(:classroom) }
      let(:other_student) { create(:student, classroom: other_classroom) }

      it "returns 404" do
        post teacher_student_password_reset_path(other_student)
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end