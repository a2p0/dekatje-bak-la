require "rails_helper"

RSpec.describe "Teacher::Parts", type: :request do
  let(:user) { create(:user, confirmed_at: Time.current) }
  let(:subject_obj) { create(:subject, owner: user) }
  let(:part) { create(:part, :specific, subject: subject_obj) }

  before { sign_in user }

  describe "GET /teacher/subjects/:subject_id/parts/:id" do
    it "returns 200" do
      get teacher_subject_part_path(subject_obj, part)
      expect(response).to have_http_status(:ok)
    end

    it "redirects for subject owned by another teacher" do
      other_subject = create(:subject)
      other_part = create(:part, subject: other_subject)
      get teacher_subject_part_path(other_subject, other_part)
      expect(response).to redirect_to(teacher_subjects_path)
    end
  end
end
