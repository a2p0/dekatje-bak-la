require "rails_helper"

RSpec.describe ExamSession, type: :model do
  describe "validations" do
    it "is valid with all required attributes" do
      exam_session = build(:exam_session)
      expect(exam_session).to be_valid
    end

    it "requires title" do
      exam_session = build(:exam_session, title: nil)
      expect(exam_session).not_to be_valid
      expect(exam_session.errors[:title]).to be_present
    end

    it "requires year" do
      exam_session = build(:exam_session, year: nil)
      expect(exam_session).not_to be_valid
      expect(exam_session.errors[:year]).to be_present
    end

    it "requires region" do
      exam_session = build(:exam_session, region: nil)
      expect(exam_session).not_to be_valid
      expect(exam_session.errors[:region]).to be_present
    end

    it "requires exam" do
      exam_session = build(:exam_session, exam: nil)
      expect(exam_session).not_to be_valid
      expect(exam_session.errors[:exam]).to be_present
    end
  end

  describe "enums" do
    it "defines region enum" do
      expect(ExamSession.regions).to eq(
        "metropole" => 0, "reunion" => 1, "polynesie" => 2, "candidat_libre" => 3
      )
    end

    it "defines exam enum" do
      expect(ExamSession.exams).to eq("bac" => 0, "bts" => 1, "autre" => 2)
    end

    it "defines variante enum" do
      expect(ExamSession.variantes).to eq("normale" => 0, "remplacement" => 1)
    end
  end

  describe "associations" do
    it "belongs to owner" do
      exam_session = build(:exam_session)
      expect(exam_session.owner).to be_a(User)
    end

    it "has many subjects with restrict_with_error on destroy" do
      exam_session = create(:exam_session)
      subject_obj = create(:subject, exam_session: exam_session)

      expect(exam_session.subjects).to include(subject_obj)
      expect { exam_session.destroy }.not_to change(ExamSession, :count)
      expect(exam_session.errors[:base]).to be_present
    end

    it "has many common_parts scoped to section_type common" do
      exam_session = create(:exam_session)
      subject_obj = create(:subject, exam_session: exam_session)
      common_part = create(:part, :common_shared, exam_session: exam_session)
      specific_part = create(:part, subject: subject_obj, section_type: :specific, specialty: :ITEC)

      expect(exam_session.common_parts).to include(common_part)
      expect(exam_session.common_parts).not_to include(specific_part)
    end
  end
end
