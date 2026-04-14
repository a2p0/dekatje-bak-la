require "rails_helper"

RSpec.describe "Teacher::Profile (Devise registration)", type: :request do
  let(:password) { "password123" }
  let(:user)     { create(:user, password: password, confirmed_at: Time.current) }

  before { sign_in user }

  describe "GET /users/edit" do
    it "returns 200" do
      get edit_user_registration_path
      expect(response).to have_http_status(:ok)
    end

    it "does not expose the plaintext openrouter key in the response body" do
      user.update!(openrouter_api_key: "or-secret-key-xyz")
      get edit_user_registration_path
      expect(response.body).not_to include("or-secret-key-xyz")
    end
  end

  describe "PUT /users (account update)" do
    it "stores a new openrouter_api_key" do
      put user_registration_path, params: {
        user: { openrouter_api_key: "or-test-key-abc123", current_password: password }
      }

      expect(user.reload.openrouter_api_key).to eq("or-test-key-abc123")
    end

    it "keeps the existing key when the field is submitted blank" do
      user.update!(openrouter_api_key: "or-existing-key")

      put user_registration_path, params: {
        user: { openrouter_api_key: "", current_password: password }
      }

      expect(user.reload.openrouter_api_key).to eq("or-existing-key")
    end

    it "replaces an existing key when a new non-blank value is submitted" do
      user.update!(openrouter_api_key: "or-old-key")

      put user_registration_path, params: {
        user: { openrouter_api_key: "or-new-key", current_password: password }
      }

      expect(user.reload.openrouter_api_key).to eq("or-new-key")
    end
  end

  describe "encryption at rest" do
    it "stores openrouter_api_key encrypted (ciphertext differs from plaintext)" do
      user.update!(openrouter_api_key: "or-test-plain")

      raw = ActiveRecord::Base.connection
        .select_value("SELECT openrouter_api_key FROM users WHERE id = #{user.id}")

      expect(raw).to be_present
      expect(raw).not_to include("or-test-plain")
    end
  end
end
