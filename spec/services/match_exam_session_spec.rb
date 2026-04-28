require "rails_helper"

RSpec.describe MatchExamSession do
  let(:teacher)  { create(:user) }
  let(:other)    { create(:user) }
  let!(:session) { create(:exam_session, owner: teacher, title: "CIME 2024", year: "2024") }

  def call(owner:, title:, year:)
    described_class.call(owner: owner, title: title, year: year)
  end

  describe "exact match" do
    it "returns the session when title and year match" do
      expect(call(owner: teacher, title: "CIME 2024", year: "2024")).to eq(session)
    end
  end

  describe "case-insensitive title matching" do
    it "finds session regardless of title casing" do
      expect(call(owner: teacher, title: "cime 2024", year: "2024")).to eq(session)
    end

    it "finds session with different casing" do
      expect(call(owner: teacher, title: "CIME 2024", year: "2024")).to eq(session)
    end
  end

  describe "whitespace trimming" do
    it "finds session ignoring leading/trailing spaces in title" do
      expect(call(owner: teacher, title: "  CIME 2024  ", year: "2024")).to eq(session)
    end
  end

  describe "no match cases" do
    it "returns nil when year does not match" do
      expect(call(owner: teacher, title: "CIME 2024", year: "2025")).to be_nil
    end

    it "returns nil when title does not match" do
      expect(call(owner: teacher, title: "Other Exam", year: "2024")).to be_nil
    end

    it "returns nil when no sessions exist for teacher" do
      new_teacher = create(:user)
      expect(call(owner: new_teacher, title: "CIME 2024", year: "2024")).to be_nil
    end
  end

  describe "cross-teacher isolation" do
    it "does not return sessions owned by another teacher" do
      other_session = create(:exam_session, owner: other, title: "CIME 2024", year: "2024")
      expect(call(owner: teacher, title: "CIME 2024", year: "2024")).not_to eq(other_session)
    end
  end

  describe "nil title or year" do
    it "returns nil when title is nil" do
      expect(call(owner: teacher, title: nil, year: "2024")).to be_nil
    end

    it "returns nil when year is nil" do
      expect(call(owner: teacher, title: "CIME 2024", year: nil)).to be_nil
    end

    it "returns nil when both are nil" do
      expect(call(owner: teacher, title: nil, year: nil)).to be_nil
    end

    it "returns nil when title is blank string" do
      expect(call(owner: teacher, title: "", year: "2024")).to be_nil
    end
  end
end
