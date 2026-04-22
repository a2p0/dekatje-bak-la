require "rails_helper"

RSpec.describe AuthenticateStudent do
  let(:classroom) { create(:classroom, access_code: "terminale-sin-2026") }
  let!(:student)  { create(:student, username: "jean.dupont", password: "password123", classroom: classroom) }

  describe ".call" do
    it "returns the student on success" do
      result = described_class.call(
        access_code: "terminale-sin-2026",
        username: "jean.dupont",
        password: "password123"
      )
      expect(result).to eq(student)
    end

    it "returns nil if classroom not found" do
      result = described_class.call(
        access_code: "inexistant",
        username: "jean.dupont",
        password: "password123"
      )
      expect(result).to be_nil
    end

    it "returns nil if username not found in classroom" do
      result = described_class.call(
        access_code: "terminale-sin-2026",
        username: "inconnu",
        password: "password123"
      )
      expect(result).to be_nil
    end

    it "returns nil if password is wrong" do
      result = described_class.call(
        access_code: "terminale-sin-2026",
        username: "jean.dupont",
        password: "mauvais"
      )
      expect(result).to be_nil
    end
  end
end