require "rails_helper"

RSpec.describe "Teacher::Classrooms::StudentImports", type: :request do
  let(:user) { create(:user, confirmed_at: Time.current) }
  let(:classroom) { create(:classroom, owner: user) }

  before { sign_in user }

  describe "GET /teacher/classrooms/:classroom_id/student_import/new" do
    it "returns 200" do
      get new_teacher_classroom_student_import_path(classroom)
      expect(response).to have_http_status(:ok)
    end

    context "when the classroom belongs to another teacher" do
      let(:other_classroom) { create(:classroom) }

      it "returns 404" do
        get new_teacher_classroom_student_import_path(other_classroom)
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "POST /teacher/classrooms/:classroom_id/student_import" do
    context "with a valid student list" do
      it "creates the students and redirects with a notice" do
        expect {
          post teacher_classroom_student_import_path(classroom),
               params: { students_list: "Jean Dupont\nMarie Martin\nPaul Bernard" }
        }.to change(Student, :count).by(3)

        expect(response).to redirect_to(teacher_classroom_path(classroom))
        follow_redirect!
        expect(flash[:notice]).to match(/3 élèves ajoutés/i)
      end

      it "stores generated credentials in the session" do
        post teacher_classroom_student_import_path(classroom),
             params: { students_list: "Jean Dupont" }
        expect(session[:generated_credentials]).to be_present
        expect(session[:generated_credentials].first["name"]).to eq("Jean Dupont")
        expect(session[:generated_credentials].first["username"]).to be_present
        expect(session[:generated_credentials].first["password"]).to be_present
      end
    end

    context "with an invalid line (missing last name)" do
      it "processes valid lines and reports the invalid one in flash alert" do
        expect {
          post teacher_classroom_student_import_path(classroom),
               params: { students_list: "Jean\nMarie Martin" }
        }.to change(Student, :count).by(1)

        follow_redirect!
        expect(flash[:alert]).to match(/format invalide/i)
      end
    end

    context "with an empty students_list" do
      it "does not create any student and does not raise" do
        expect {
          post teacher_classroom_student_import_path(classroom), params: { students_list: "" }
        }.not_to change(Student, :count)

        expect(response).to redirect_to(teacher_classroom_path(classroom))
      end
    end

    context "when the classroom belongs to another teacher" do
      let(:other_classroom) { create(:classroom) }

      it "returns 404" do
        post teacher_classroom_student_import_path(other_classroom),
             params: { students_list: "Jean Dupont" }
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end