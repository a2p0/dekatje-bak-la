require "rails_helper"

RSpec.describe Part, type: :model do
  describe "validations" do
    it "is valid with required attributes" do
      part = build(:part)
      expect(part).to be_valid
    end

    it "requires number" do
      part = build(:part, number: nil)
      expect(part).not_to be_valid
    end

    it "requires title" do
      part = build(:part, title: nil)
      expect(part).not_to be_valid
    end
  end

  describe "enums" do
    it "defines section_type enum" do
      expect(Part.section_types).to eq("common" => 0, "specific" => 1)
    end
  end

  describe "associations" do
    it "belongs to subject" do
      part = build(:part)
      expect(part.subject).to be_a(Subject)
    end

    it "has many questions" do
      part = create(:part)
      expect(part).to respond_to(:questions)
    end
  end
end
