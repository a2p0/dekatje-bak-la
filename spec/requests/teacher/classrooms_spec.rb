require "rails_helper"

RSpec.describe "Teacher::Classrooms", type: :request do
  let(:user) { create(:user, confirmed_at: Time.current) }

  before { sign_in user }

  describe "GET /teacher" do
    it "returns 200" do
      get teacher_root_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /teacher/classrooms/new" do
    it "returns 200" do
      get new_teacher_classroom_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /teacher/classrooms" do
    it "creates a classroom and redirects" do
      expect {
        post teacher_classrooms_path, params: { classroom: { name: "Terminale SIN", school_year: "2026", specialty: "SIN" } }
      }.to change(Classroom, :count).by(1)
      expect(response).to redirect_to(teacher_classroom_path(Classroom.last))
    end
  end

  describe "GET /teacher/classrooms/:id" do
    let(:classroom) { create(:classroom, owner: user) }

    it "returns 200" do
      get teacher_classroom_path(classroom)
      expect(response).to have_http_status(:ok)
    end

    it "redirects for classroom owned by another teacher" do
      other_classroom = create(:classroom)
      get teacher_classroom_path(other_classroom)
      expect(response).to redirect_to(teacher_root_path)
    end
  end

  describe "GET /teacher/classrooms/:id/edit" do
    let(:classroom) { create(:classroom, owner: user) }

    it "returns 200" do
      get edit_teacher_classroom_path(classroom)
      expect(response).to have_http_status(:ok)
    end

    it "redirects for classroom owned by another teacher" do
      other_classroom = create(:classroom)
      get edit_teacher_classroom_path(other_classroom)
      expect(response).to redirect_to(teacher_root_path)
    end
  end

  describe "PATCH /teacher/classrooms/:id" do
    let(:classroom) { create(:classroom, owner: user, tutor_free_mode_enabled: false) }

    it "updates tutor_free_mode_enabled to true" do
      patch teacher_classroom_path(classroom),
            params: { classroom: { tutor_free_mode_enabled: true } }

      expect(classroom.reload.tutor_free_mode_enabled).to be(true)
      expect(response).to redirect_to(teacher_classroom_path(classroom))
    end

    it "updates tutor_free_mode_enabled back to false" do
      classroom.update!(tutor_free_mode_enabled: true)

      patch teacher_classroom_path(classroom),
            params: { classroom: { tutor_free_mode_enabled: false } }

      expect(classroom.reload.tutor_free_mode_enabled).to be(false)
    end

    it "ignores unpermitted params (strong params guard)" do
      other_teacher = create(:user, confirmed_at: Time.current)

      patch teacher_classroom_path(classroom),
            params: { classroom: { tutor_free_mode_enabled: true, owner_id: other_teacher.id } }

      expect(classroom.reload.owner_id).to eq(user.id)
    end

    it "redirects for classroom owned by another teacher" do
      other_classroom = create(:classroom)
      patch teacher_classroom_path(other_classroom),
            params: { classroom: { tutor_free_mode_enabled: true } }

      expect(response).to redirect_to(teacher_root_path)
    end
  end

  describe "unauthenticated" do
    before { sign_out user }

    it "redirects to login" do
      get teacher_root_path
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe "unconfirmed user" do
    let(:unconfirmed) { create(:user, confirmed_at: nil) }
    before { sign_in unconfirmed }

    it "redirects to login" do
      get teacher_root_path
      expect(response).to redirect_to(new_user_session_path)
    end
  end
end