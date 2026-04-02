require "rails_helper"

RSpec.describe "Student::Tutor", type: :request do
  let(:classroom) { create(:classroom) }
  let(:student) { create(:student, classroom: classroom) }
  let(:subject_obj) { create(:subject, status: :published) }
  let(:part) { create(:part, subject: subject_obj, position: 1) }
  let(:question) do
    create(:question, part: part, position: 1, answer_type: :calculation)
  end
  let!(:answer) do
    create(:answer, question: question, data_hints: [
      { "source" => "DT1", "location" => "tableau Consommation" },
      { "source" => "mise_en_situation", "location" => "distance Troyes-Le Bourget" }
    ])
  end
  let!(:student_session) do
    create(:student_session, student: student, subject: subject_obj, mode: :tutored)
  end

  before do
    create(:classroom_subject, classroom: classroom, subject: subject_obj)
    post student_session_path(access_code: classroom.access_code),
         params: { username: student.username, password: "password123" }
  end

  let(:turbo_headers) { { "Accept" => "text/vnd.turbo-stream.html" } }

  def verify_path
    student_tutor_question_verify_spotting_path(
      access_code: classroom.access_code,
      subject_id: subject_obj.id,
      question_id: question.id
    )
  end

  def skip_path
    student_tutor_question_skip_spotting_path(
      access_code: classroom.access_code,
      subject_id: subject_obj.id,
      question_id: question.id
    )
  end

  describe "POST activate" do
    def activate_path
      student_tutor_activate_path(
        access_code: classroom.access_code,
        subject_id: subject_obj.id
      )
    end

    context "when student is in autonomous mode" do
      before { student_session.update!(mode: :autonomous) }

      it "switches mode to tutored and redirects back" do
        post activate_path

        student_session.reload
        expect(student_session.mode).to eq("tutored")
        expect(response).to redirect_to(student_subject_path(access_code: classroom.access_code, id: subject_obj.id))
      end
    end

    context "when student is already in tutored mode" do
      it "stays tutored without error and redirects" do
        post activate_path

        student_session.reload
        expect(student_session.mode).to eq("tutored")
        expect(response).to redirect_to(student_subject_path(access_code: classroom.access_code, id: subject_obj.id))
      end
    end
  end

  describe "POST verify_spotting" do
    context "with correct task_type and correct sources" do
      it "stores feedback with all correct, sets step to feedback, returns turbo_stream" do
        post verify_path,
             params: { task_type: "calculation", sources: %w[dt mise_en_situation] },
             headers: turbo_headers

        expect(response.content_type).to include("text/vnd.turbo-stream.html")

        student_session.reload
        expect(student_session.question_step(question.id)).to eq("feedback")

        spotting = student_session.spotting_data(question.id)
        expect(spotting["task_type_correct"]).to be true
        expect(spotting["sources_missed"]).to be_empty
        expect(spotting["sources_extra"]).to be_empty
      end
    end

    context "with wrong task_type" do
      it "stores task_type_correct: false" do
        post verify_path,
             params: { task_type: "text", sources: %w[dt mise_en_situation] },
             headers: turbo_headers

        student_session.reload
        spotting = student_session.spotting_data(question.id)
        expect(spotting["task_type_correct"]).to be false
      end
    end

    context "with missing sources" do
      it "stores sources_missed populated" do
        post verify_path,
             params: { task_type: "calculation", sources: %w[dt] },
             headers: turbo_headers

        student_session.reload
        spotting = student_session.spotting_data(question.id)
        missed_sources = spotting["sources_missed"].map { |s| s["source"] }
        expect(missed_sources).to include("mise_en_situation")
        expect(spotting["sources_extra"]).to be_empty
      end
    end

    context "with extra sources" do
      it "stores sources_extra populated" do
        post verify_path,
             params: { task_type: "calculation", sources: %w[dt mise_en_situation enonce] },
             headers: turbo_headers

        student_session.reload
        spotting = student_session.spotting_data(question.id)
        expect(spotting["sources_extra"]).to include("enonce")
        expect(spotting["sources_missed"]).to be_empty
      end
    end

    context "with question without data_hints" do
      let!(:answer) { create(:answer, question: question, data_hints: []) }

      it "only validates task_type (no sources check)" do
        post verify_path,
             params: { task_type: "calculation", sources: [] },
             headers: turbo_headers

        student_session.reload
        spotting = student_session.spotting_data(question.id)
        expect(spotting["task_type_correct"]).to be true
        expect(spotting["sources_missed"]).to be_empty
        expect(spotting["sources_extra"]).to be_empty
      end
    end

    context "when student is in autonomous mode" do
      before do
        student_session.update!(mode: :autonomous)
      end

      it "returns an error or redirects" do
        post verify_path,
             params: { task_type: "calculation", sources: %w[dt] },
             headers: turbo_headers

        expect(response.status).to eq(403)
      end
    end
  end

  describe "POST skip_spotting" do
    context "when skipping" do
      it "sets step to skipped and returns turbo_stream" do
        post skip_path, headers: turbo_headers

        expect(response.content_type).to include("text/vnd.turbo-stream.html")

        student_session.reload
        expect(student_session.question_step(question.id)).to eq("skipped")
      end
    end

    context "when already completed" do
      before do
        student_session.set_question_step!(question.id, "feedback")
      end

      it "does not change the step" do
        post skip_path, headers: turbo_headers

        student_session.reload
        expect(student_session.question_step(question.id)).to eq("feedback")
      end
    end
  end
end
