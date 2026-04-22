require "rails_helper"

RSpec.describe Student, type: :model do
  describe "validations" do
    it "requires first_name" do
      student = build(:student, first_name: nil)
      expect(student).not_to be_valid
      expect(student.errors[:first_name]).to include("can't be blank")
    end

    it "requires last_name" do
      student = build(:student, last_name: nil)
      expect(student).not_to be_valid
      expect(student.errors[:last_name]).to include("can't be blank")
    end

    it "requires username" do
      student = build(:student, username: nil)
      expect(student).not_to be_valid
      expect(student.errors[:username]).to include("can't be blank")
    end

    it "requires password" do
      student = build(:student, password: nil)
      expect(student).not_to be_valid
    end

    it "validates uniqueness of username scoped to classroom" do
      classroom = create(:classroom)
      create(:student, username: "jean.dupont", classroom: classroom)
      duplicate = build(:student, username: "jean.dupont", classroom: classroom)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:username]).to be_present
    end

    it "allows same username in different classrooms" do
      create(:student, username: "jean.dupont", classroom: create(:classroom))
      other = build(:student, username: "jean.dupont", classroom: create(:classroom))
      expect(other).to be_valid
    end
  end

  describe "associations" do
    it "belongs to a classroom" do
      student = build(:student)
      expect(student.classroom).to be_a(Classroom)
    end
  end

  describe "enums" do
    it "defines api_provider enum with correct values" do
      expect(Student.api_providers).to eq("openrouter" => 0, "anthropic" => 1, "openai" => 2, "google" => 3)
    end
  end

  describe "authentication" do
    it "authenticates with correct password" do
      student = create(:student, password: "secret123")
      expect(student.authenticate("secret123")).to eq(student)
    end

    it "rejects incorrect password" do
      student = create(:student, password: "secret123")
      expect(student.authenticate("wrong")).to be_falsey
    end
  end
end