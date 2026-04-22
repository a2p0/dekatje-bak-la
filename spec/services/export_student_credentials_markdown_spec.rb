require "rails_helper"

RSpec.describe ExportStudentCredentialsMarkdown do
  let(:owner) { create(:user) }
  let(:classroom) { create(:classroom, name: "Terminale SIN", school_year: "2026", access_code: "terminale-sin-2026", owner: owner) }

  before do
    create(:student, first_name: "Jean", last_name: "Dupont", username: "jean.dupont", classroom: classroom)
    create(:student, first_name: "Marie", last_name: "Martin", username: "marie.martin", classroom: classroom)
  end

  describe ".call" do
    subject(:result) { described_class.call(classroom: classroom) }

    it "returns a string" do
      expect(result).to be_a(String)
    end

    it "includes the classroom name" do
      expect(result).to include("Terminale SIN")
    end

    it "includes the access code URL" do
      expect(result).to include("terminale-sin-2026")
    end

    it "includes a markdown table header" do
      expect(result).to include("| Nom | Identifiant | Mot de passe |")
    end

    it "includes all student usernames" do
      expect(result).to include("jean.dupont")
      expect(result).to include("marie.martin")
    end

    it "includes student full names" do
      expect(result).to include("Dupont Jean")
      expect(result).to include("Martin Marie")
    end

    it "marks password column as to distribute" do
      expect(result).to include("_(à distribuer)_")
    end
  end
end