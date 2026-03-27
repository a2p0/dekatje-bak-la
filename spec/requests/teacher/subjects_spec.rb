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
      own_subject = create(:subject, owner: user)
      other_subject = create(:subject)
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
          exam_type: "bac",
          specialty: "SIN",
          region: "metropole",
          enonce_file: pdf_upload("enonce.pdf"),
          dt_file: pdf_upload("dt.pdf"),
          dr_vierge_file: pdf_upload("dr_vierge.pdf"),
          dr_corrige_file: pdf_upload("dr_corrige.pdf"),
          questions_corrigees_file: pdf_upload("questions_corrigees.pdf")
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
          subject: { title: "Test", year: "2026", exam_type: "bac", specialty: "SIN", region: "metropole" }
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

  describe "PATCH /teacher/subjects/:id/publish" do
    it "publishes a pending_validation subject" do
      subject = create(:subject, owner: user, status: :pending_validation)
      patch publish_teacher_subject_path(subject)
      expect(subject.reload.status).to eq("published")
    end

    it "does not publish an archived subject" do
      subject = create(:subject, owner: user, status: :archived)
      patch publish_teacher_subject_path(subject)
      expect(subject.reload.status).to eq("archived")
    end
  end

  describe "PATCH /teacher/subjects/:id/archive" do
    it "archives a published subject" do
      subject = create(:subject, owner: user, status: :published)
      patch archive_teacher_subject_path(subject)
      expect(subject.reload.status).to eq("archived")
    end

    it "does not archive a draft subject" do
      subject = create(:subject, owner: user, status: :draft)
      patch archive_teacher_subject_path(subject)
      expect(subject.reload.status).to eq("draft")
    end
  end
end
