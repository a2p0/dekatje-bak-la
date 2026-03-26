require "rails_helper"

RSpec.describe GenerateStudentCredentials do
  let(:classroom) { create(:classroom) }

  describe ".call" do
    it "generates username from first and last name" do
      result = described_class.call(first_name: "Jean", last_name: "Dupont", classroom: classroom)
      expect(result[:username]).to eq("jean.dupont")
    end

    it "adds numeric suffix on username collision within same classroom" do
      create(:student, username: "jean.dupont", classroom: classroom)
      result = described_class.call(first_name: "Jean", last_name: "Dupont", classroom: classroom)
      expect(result[:username]).to eq("jean.dupont2")
    end

    it "increments suffix until unique" do
      create(:student, username: "jean.dupont", classroom: classroom)
      create(:student, username: "jean.dupont2", classroom: classroom)
      result = described_class.call(first_name: "Jean", last_name: "Dupont", classroom: classroom)
      expect(result[:username]).to eq("jean.dupont3")
    end

    it "returns a password of 8 characters" do
      result = described_class.call(first_name: "Jean", last_name: "Dupont", classroom: classroom)
      expect(result[:password].length).to eq(8)
    end

    it "returns a password with only unambiguous alphanumeric characters" do
      result = described_class.call(first_name: "Jean", last_name: "Dupont", classroom: classroom)
      expect(result[:password]).to match(/\A[a-km-np-z2-9]+\z/)
    end

    it "allows same username in different classrooms" do
      other_classroom = create(:classroom)
      create(:student, username: "jean.dupont", classroom: other_classroom)
      result = described_class.call(first_name: "Jean", last_name: "Dupont", classroom: classroom)
      expect(result[:username]).to eq("jean.dupont")
    end
  end
end
