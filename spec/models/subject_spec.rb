require "rails_helper"

RSpec.describe Subject, type: :model do
  describe "validations" do
    it "is valid with all required attributes and files" do
      subject_obj = build(:subject)
      expect(subject_obj).to be_valid
    end

    it "requires title" do
      subject_obj = build(:subject, title: nil)
      expect(subject_obj).not_to be_valid
      expect(subject_obj.errors[:title]).to be_present
    end

    it "requires year" do
      subject_obj = build(:subject, year: nil)
      expect(subject_obj).not_to be_valid
    end

    it "requires exam_type" do
      subject_obj = build(:subject, exam_type: nil)
      expect(subject_obj).not_to be_valid
    end

    it "requires specialty" do
      subject_obj = build(:subject, specialty: nil)
      expect(subject_obj).not_to be_valid
    end

    it "requires region" do
      subject_obj = build(:subject, region: nil)
      expect(subject_obj).not_to be_valid
    end
  end

  describe "enums" do
    it "defines exam_type enum" do
      expect(Subject.exam_types).to eq("bac" => 0, "bts" => 1, "autre" => 2)
    end

    it "defines specialty enum" do
      expect(Subject.specialties).to eq(
        "tronc_commun" => 0, "SIN" => 1, "ITEC" => 2, "EC" => 3, "AC" => 4
      )
    end

    it "defines region enum" do
      expect(Subject.regions).to eq(
        "metropole" => 0, "drom_com" => 1, "polynesie" => 2, "candidat_libre" => 3
      )
    end

    it "defines status enum with draft as default" do
      subject_obj = build(:subject)
      expect(subject_obj.status).to eq("draft")
    end
  end

  describe "associations" do
    it "belongs to owner" do
      subject_obj = build(:subject)
      expect(subject_obj.owner).to be_a(User)
    end
  end

  describe "scopes" do
    it "kept excludes soft-deleted subjects" do
      kept = create(:subject)
      deleted = create(:subject, discarded_at: Time.current)
      expect(Subject.kept).to include(kept)
      expect(Subject.kept).not_to include(deleted)
    end
  end

  describe "ActiveStorage attachments" do
    it "has enonce_file attached" do
      subject_obj = create(:subject)
      expect(subject_obj.enonce_file).to be_attached
    end

    it "has dt_file attached" do
      subject_obj = create(:subject)
      expect(subject_obj.dt_file).to be_attached
    end

    it "has dr_vierge_file attached" do
      subject_obj = create(:subject)
      expect(subject_obj.dr_vierge_file).to be_attached
    end

    it "has dr_corrige_file attached" do
      subject_obj = create(:subject)
      expect(subject_obj.dr_corrige_file).to be_attached
    end

    it "has questions_corrigees_file attached" do
      subject_obj = create(:subject)
      expect(subject_obj.questions_corrigees_file).to be_attached
    end
  end
end
