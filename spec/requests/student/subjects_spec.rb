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

  # Part/subject completion coverage moved to :
  # - spec/requests/student/subjects/part_completions_spec.rb
  # - spec/requests/student/subjects/completions_spec.rb
  # (refactored to RESTful Student::Subjects::PartCompletionsController / CompletionsController)

  describe "GET /subjects/:id — tutor status indicator (T100)" do
    let!(:part) { create(:part, :specific, subject: subject_obj, position: 1) }
    let!(:question) { create(:question, part: part, position: 1) }

    def get_show
      get student_subject_path(access_code: classroom.access_code, id: subject_obj.id)
    end

    context "when student has no API key and free mode is disabled" do
      it "shows unavailable indicator" do
        get_show
        expect(response.body).to include("Tuteur indisponible")
      end

      it "shows a link to settings" do
        get_show
        expect(response.body).to include("Paramétrer")
      end
    end

    context "when student has an API key, no active conversation" do
      before { student.update!(api_key: "sk-test", use_personal_key: true) }

      it "shows available indicator" do
        get_show
        expect(response.body).to include("Tuteur disponible")
      end
    end

    context "when student has an active conversation on this subject" do
      before do
        student.update!(api_key: "sk-test", use_personal_key: true)
        create(:conversation, student: student, subject: subject_obj, lifecycle_state: "active")
      end

      it "shows active indicator" do
        get_show
        expect(response.body).to include("Tuteur actif")
      end
    end

    context "when student has use_personal_key enabled with key (no active conversation)" do
      before { student.update!(api_key: "sk-test", use_personal_key: true) }

      it "shows available indicator (not active without conversation)" do
        get_show
        expect(response.body).to include("Tuteur disponible")
      end
    end

    it "does not show an activate button in any state" do
      get_show
      expect(response.body).not_to include("Activer le tuteur")
    end
  end
end