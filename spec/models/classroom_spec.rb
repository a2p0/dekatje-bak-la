require "rails_helper"

RSpec.describe Classroom, type: :model do
  describe "validations" do
    it "is valid with all required attributes" do
      classroom = build(:classroom)
      expect(classroom).to be_valid
    end

    it "is invalid without a name" do
      classroom = build(:classroom, name: nil)
      expect(classroom).not_to be_valid
      expect(classroom.errors[:name]).to include("can't be blank")
    end

    it "is invalid without a school_year" do
      classroom = build(:classroom, school_year: nil)
      expect(classroom).not_to be_valid
      expect(classroom.errors[:school_year]).to include("can't be blank")
    end

    it "is invalid without an access_code" do
      classroom = build(:classroom, access_code: nil)
      expect(classroom).not_to be_valid
      expect(classroom.errors[:access_code]).to include("can't be blank")
    end

    it "is invalid with a duplicate access_code" do
      create(:classroom, access_code: "terminale-sin-abc123")
      duplicate = build(:classroom, access_code: "terminale-sin-abc123")
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:access_code]).to include("has already been taken")
    end
  end

  describe "associations" do
    it "belongs to an owner (User)" do
      classroom = build(:classroom)
      expect(classroom.owner).to be_a(User)
    end

    it "has many students" do
      classroom = create(:classroom)
      expect(classroom).to respond_to(:students)
    end

    it "declares dependent destroy for students" do
      reflection = Classroom.reflect_on_association(:students)
      expect(reflection).not_to be_nil
      expect(reflection.options[:dependent]).to eq(:destroy)
    end
  end
end
