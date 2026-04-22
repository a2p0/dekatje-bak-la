require "rails_helper"

RSpec.describe GenerateAccessCode do
  describe ".call" do
    it "generates a slug from specialty and school_year" do
      result = described_class.call(specialty: "SIN", school_year: "2026")
      expect(result).to eq("sin-2026")
    end

    it "adds numeric suffix on collision" do
      create(:classroom, access_code: "sin-2026")
      result = described_class.call(specialty: "SIN", school_year: "2026")
      expect(result).to eq("sin-2026-2")
    end

    it "increments suffix until unique" do
      create(:classroom, access_code: "sin-2026")
      create(:classroom, access_code: "sin-2026-2")
      result = described_class.call(specialty: "SIN", school_year: "2026")
      expect(result).to eq("sin-2026-3")
    end

    it "handles nil specialty" do
      result = described_class.call(specialty: nil, school_year: "2026")
      expect(result).to eq("2026")
    end
  end
end