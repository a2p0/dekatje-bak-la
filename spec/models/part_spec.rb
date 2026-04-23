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

  describe "dual FK validation (exactly_one_owner)" do
    it "is valid with subject only (specific part)" do
      part = build(:part, :specific)
      expect(part).to be_valid
    end

    it "is valid with exam_session only (common shared part)" do
      part = build(:part, :common_shared)
      expect(part).to be_valid
    end

    it "is invalid with both exam_session and subject" do
      part = build(:part, exam_session: create(:exam_session))
      expect(part).not_to be_valid
      expect(part.errors[:base]).to include("must belong to either a subject or an exam_session, not both")
    end

    it "is invalid with neither exam_session nor subject" do
      part = build(:part, subject: nil, exam_session: nil)
      expect(part).not_to be_valid
      expect(part.errors[:base]).to include("must belong to either a subject or an exam_session")
    end
  end

  describe "enums" do
    it "defines section_type enum" do
      expect(Part.section_types).to eq("common" => 0, "specific" => 1)
    end

    it "defines specialty enum with prefix" do
      expect(Part.specialties).to eq("SIN" => 0, "ITEC" => 1, "EE" => 2, "AC" => 3)
    end

    it "uses prefixed specialty methods" do
      part = build(:part, specialty: :SIN)
      expect(part.specialty_SIN?).to be true
    end
  end

  describe "associations" do
    it "belongs to subject" do
      part = build(:part)
      expect(part.subject).to be_a(Subject)
    end

    it "belongs to exam_session" do
      part = build(:part, :common_shared)
      expect(part.exam_session).to be_a(ExamSession)
    end

    it "has many questions" do
      part = create(:part)
      expect(part).to respond_to(:questions)
    end
  end
end
