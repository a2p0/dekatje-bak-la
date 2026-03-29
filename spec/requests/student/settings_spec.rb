require "rails_helper"

RSpec.describe "Student::Settings", type: :request do
  let(:classroom) { create(:classroom) }
  let(:student) { create(:student, classroom: classroom) }

  before do
    post student_session_path(access_code: classroom.access_code),
         params: { username: student.username, password: "password123" }
  end

  describe "GET /settings" do
    it "returns 200" do
      get student_settings_path(access_code: classroom.access_code)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "PATCH /settings" do
    it "updates default_mode" do
      patch student_settings_path(access_code: classroom.access_code),
            params: { student: { default_mode: "tutored" } }
      expect(student.reload.default_mode).to eq("tutored")
      expect(response).to redirect_to(student_settings_path(access_code: classroom.access_code))
    end

    it "updates api_provider and api_model" do
      patch student_settings_path(access_code: classroom.access_code),
            params: { student: { api_provider: "anthropic", api_model: "claude-haiku-4-5-20251001" } }
      student.reload
      expect(student.api_provider).to eq("anthropic")
      expect(student.api_model).to eq("claude-haiku-4-5-20251001")
    end

    it "updates api_key (encrypted)" do
      patch student_settings_path(access_code: classroom.access_code),
            params: { student: { api_key: "sk-test-key-123" } }
      expect(student.reload.api_key).to eq("sk-test-key-123")
    end
  end

  describe "POST /settings/test_key" do
    it "returns turbo stream with valid result" do
      allow(ValidateStudentApiKey).to receive(:call)
        .and_return({ valid: true })

      post student_test_key_path(access_code: classroom.access_code),
           params: { provider: "anthropic", api_key: "sk-test", model: "claude-haiku-4-5-20251001" },
           headers: { "Accept" => "text/vnd.turbo-stream.html" }
      expect(response.body).to include("valide")
    end

    it "returns turbo stream with error for bad key" do
      allow(ValidateStudentApiKey).to receive(:call)
        .and_return({ valid: false, error: "API error 401: Unauthorized" })

      post student_test_key_path(access_code: classroom.access_code),
           params: { provider: "anthropic", api_key: "bad", model: "claude-haiku-4-5-20251001" },
           headers: { "Accept" => "text/vnd.turbo-stream.html" }
      expect(response.body).to include("401")
    end
  end
end
