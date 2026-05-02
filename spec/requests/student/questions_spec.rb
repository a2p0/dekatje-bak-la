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

    it "uses Radical cream background" do
      get student_question_path(access_code: classroom.access_code, subject_id: subject_obj.id, id: question.id)
      expect(response.body).to include("bg-rad-bg")
    end

    it "renders stripes" do
      get student_question_path(access_code: classroom.access_code, subject_id: subject_obj.id, id: question.id)
      expect(response.body).to include("bg-rad-red")
      expect(response.body).to include("bg-rad-yellow")
    end

    it "shows compact header with subject title" do
      get student_question_path(access_code: classroom.access_code, subject_id: subject_obj.id, id: question.id)
      expect(response.body).to include(subject_obj.title)
      expect(response.body).to include("tracking-[0.16em]")
    end

    it "renders question label in serif card" do
      get student_question_path(access_code: classroom.access_code, subject_id: subject_obj.id, id: question.id)
      expect(response.body).to include("font-serif")
      expect(response.body).to include("bg-rad-red")
      expect(response.body).to include("bg-rad-paper")
    end

    context "navigation styling" do
      let!(:q2) { create(:question, part: part, position: 2) }

      it "uses rad-red for next question button" do
        get student_question_path(access_code: classroom.access_code, subject_id: subject_obj.id, id: question.id)
        expect(response.body).to include("bg-rad-red")
        expect(response.body).to include("Question suivante")
      end
    end
  end

  # Note: correction reveal is now handled by Student::Questions::CorrectionsController (POST).
  # See spec/requests/student/questions/corrections_spec.rb

  describe "correction button styling" do
    it "uses outlined rad-text style for correction button" do
      get student_question_path(access_code: classroom.access_code, subject_id: subject_obj.id, id: question.id)
      expect(response.body).to include("border-rad-text")
      expect(response.body).to include("Voir la correction")
      expect(response.body).not_to include("from-indigo-500 to-violet-500 text-white border-0 rounded-xl")
    end
  end

  describe "correction display (Radical)" do
    before do
      ss = student.student_sessions.find_or_create_by!(subject: subject_obj) do |s|
        s.mode = :autonomous; s.started_at = Time.current; s.last_activity_at = Time.current
      end
      ss.mark_answered!(question.id)
      ss.save!
    end

    it "renders correction with Radical green card" do
      get student_question_path(access_code: classroom.access_code, subject_id: subject_obj.id, id: question.id)
      expect(response.body).to include("bg-rad-green")
      expect(response.body).to include("pattern-madras")
    end

    it "renders data hints with yellow accent" do
      answer.update!(data_hints: [{ "source" => "DT1", "location" => "tableau", "value" => "30,5 L" }])
      get student_question_path(access_code: classroom.access_code, subject_id: subject_obj.id, id: question.id)
      expect(response.body).to include("bg-rad-yellow")
      expect(response.body).to include("Où trouver les données")
    end
  end

  describe "GET /subjects/:subject_id/questions/:id — tutor button (T200)" do
    def get_show
      get student_question_path(access_code: classroom.access_code, subject_id: subject_obj.id, id: question.id)
    end

    context "when student has no API key and classroom free mode is disabled" do
      it "shows 'Activer le tuteur' link instead of Tutorat button" do
        get_show
        expect(response.body).to include("Activer le tuteur")
        expect(response.body).not_to include("Tibo")
      end

      it "links to the settings page" do
        get_show
        expect(response.body).to include(student_settings_path(access_code: classroom.access_code))
      end
    end

    context "when student has an API key" do
      before { student.update!(api_key: "sk-test", use_personal_key: true) }

      it "shows the Tutorat button" do
        get_show
        expect(response.body).to include("Tibo")
        expect(response.body).not_to include("Activer le tuteur")
      end
    end

    context "when classroom free mode is enabled (no student key)" do
      let(:user) { create(:user, openrouter_api_key: "or-key") }
      let(:classroom) { create(:classroom, owner: user, tutor_free_mode_enabled: true) }

      it "shows the Tutorat button" do
        get_show
        expect(response.body).to include("Tibo")
        expect(response.body).not_to include("Activer le tuteur")
      end
    end
  end
end
