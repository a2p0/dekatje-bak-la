require "rails_helper"

RSpec.describe ExportStudentCredentialsPdf do
  let(:owner) { create(:user) }
  let(:classroom) { create(:classroom, name: "Terminale SIN", school_year: "2026", access_code: "terminale-sin-2026", owner: owner) }

  before do
    create(:student, first_name: "Jean", last_name: "Dupont", username: "jean.dupont", classroom: classroom)
  end

  describe ".call" do
    subject(:result) { described_class.call(classroom: classroom) }

    it "returns a Prawn::Document" do
      expect(result).to be_a(Prawn::Document)
    end

    it "can render to binary string" do
      expect(result.render).to be_a(String)
      expect(result.render.encoding).to eq(Encoding::ASCII_8BIT)
    end

    it "produces a non-empty PDF" do
      expect(result.render.length).to be > 1000
    end
  end
end
