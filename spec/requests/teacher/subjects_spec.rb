require "rails_helper"

RSpec.describe "Teacher::Subjects", type: :request do
  let(:user) { create(:user, confirmed_at: Time.current) }

  before { sign_in user }

  describe "GET /teacher/subjects" do
    it "returns 200" do
      get teacher_subjects_path
      expect(response).to have_http_status(:ok)
    end

    it "only shows subjects owned by current teacher" do
      own_es = create(:exam_session, owner: user, title: "Mon sujet BAC")
      own_subject = create(:subject, owner: user, exam_session: own_es)
      other_es = create(:exam_session, title: "Sujet autre prof")
      other_subject = create(:subject, exam_session: other_es)
      get teacher_subjects_path
      expect(response.body).to include(own_subject.title)
      expect(response.body).not_to include(other_subject.title)
    end
  end

  describe "GET /teacher/subjects/new" do
    it "returns 200" do
      get new_teacher_subject_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /teacher/subjects" do
    def pdf_upload(filename)
      fixture_file = Tempfile.new([ filename, ".pdf" ])
      fixture_file.write("%PDF-1.4 fake content")
      fixture_file.rewind
      Rack::Test::UploadedFile.new(fixture_file, "application/pdf", original_filename: filename)
    end

    let(:valid_params) do
      {
        subject: {
          title: "Sujet SIN 2026",
          year: "2026",
          exam: "bac",
          specialty: "SIN",
          region: "metropole",
          subject_pdf: pdf_upload("subject.pdf"),
          correction_pdf: pdf_upload("correction.pdf")
        }
      }
    end

    it "creates a subject and an extraction job" do
      expect {
        post teacher_subjects_path, params: valid_params
      }.to change(Subject, :count).by(1).and change(ExtractionJob, :count).by(1)
      expect(response).to redirect_to(teacher_subject_path(Subject.last))
    end

    it "does not create subject with missing files" do
      expect {
        post teacher_subjects_path, params: {
          subject: { title: "Test", year: "2026", exam: "bac", specialty: "SIN", region: "metropole" }
        }
      }.not_to change(Subject, :count)
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "GET /teacher/subjects/:id" do
    let(:subject) { create(:subject, owner: user) }

    it "returns 200" do
      get teacher_subject_path(subject)
      expect(response).to have_http_status(:ok)
    end

    it "redirects for subject owned by another teacher" do
      other_subject = create(:subject)
      get teacher_subject_path(other_subject)
      expect(response).to redirect_to(teacher_subjects_path)
    end
  end

  # Publish/unpublish coverage lives in spec/requests/teacher/subjects/publications_spec.rb
  # (refactored to RESTful Teacher::Subjects::PublicationsController#create/destroy)
  # Archive route was removed as orphaned (no view exposed it).
end
