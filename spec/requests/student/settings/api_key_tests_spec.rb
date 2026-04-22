require "rails_helper"

RSpec.describe "Student::Settings::ApiKeyTests", type: :request do
  let(:classroom) { create(:classroom) }
  let(:student) { create(:student, classroom: classroom) }

  before do
    post student_session_path(access_code: classroom.access_code),
         params: { username: student.username, password: "password123" }
  end

  describe "POST /settings/api_key_test" do
    context "with a valid API key" do
      it "returns a Turbo Stream response including 'valide'" do
        allow(ValidateStudentApiKey).to receive(:call).and_return(true)

        post student_api_key_test_path(access_code: classroom.access_code),
             params: { provider: "anthropic", api_key: "sk-test", model: "claude-haiku-4-5-20251001" },
             headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("valide")
      end
    end

    context "with an invalid API key" do
      it "returns a Turbo Stream response including the error message" do
        allow(ValidateStudentApiKey).to receive(:call)
          .and_raise(ValidateStudentApiKey::InvalidApiKeyError, "API error 401: Unauthorized")

        post student_api_key_test_path(access_code: classroom.access_code),
             params: { provider: "anthropic", api_key: "bad-key", model: "claude-haiku-4-5-20251001" },
             headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("401")
      end
    end

    context "without authentication" do
      before do
        delete student_session_path(access_code: classroom.access_code)
      end

      it "redirects to login" do
        post student_api_key_test_path(access_code: classroom.access_code),
             params: { provider: "anthropic", api_key: "sk-test", model: "claude-haiku-4-5-20251001" }

        expect(response).to redirect_to(student_login_path(access_code: classroom.access_code))
      end
    end
  end
end