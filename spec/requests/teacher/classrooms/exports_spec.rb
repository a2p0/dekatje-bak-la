require "rails_helper"

RSpec.describe "Teacher::Classrooms::Exports", type: :request do
  let(:user) { create(:user, confirmed_at: Time.current) }
  let(:classroom) { create(:classroom, owner: user) }

  before do
    sign_in user
    create_list(:student, 2, classroom: classroom)
  end

  describe "GET /teacher/classrooms/:classroom_id/export.pdf" do
    it "returns 200 with PDF content type and attachment disposition" do
      get teacher_classroom_export_path(classroom, format: :pdf)
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include("application/pdf")
      expect(response.headers["Content-Disposition"]).to include("attachment")
      expect(response.headers["Content-Disposition"]).to include(".pdf")
    end
  end

  describe "GET /teacher/classrooms/:classroom_id/export.markdown" do
    it "returns 200 with markdown content type and attachment disposition" do
      get teacher_classroom_export_path(classroom, format: :markdown)
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include("text/markdown")
      expect(response.headers["Content-Disposition"]).to include("attachment")
      expect(response.headers["Content-Disposition"]).to include(".md")
    end
  end

  context "when the classroom belongs to another teacher" do
    let(:other_classroom) { create(:classroom) }

    it "returns 404 for PDF export" do
      get teacher_classroom_export_path(other_classroom, format: :pdf)
      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for markdown export" do
      get teacher_classroom_export_path(other_classroom, format: :markdown)
      expect(response).to have_http_status(:not_found)
    end
  end
end
