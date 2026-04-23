require "rails_helper"

RSpec.describe "Pages", type: :request do
  describe "GET /mentions-legales" do
    it "returns success" do
      get legal_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /politique-de-confidentialite" do
    it "returns success" do
      get privacy_path
      expect(response).to have_http_status(:ok)
    end
  end
end
