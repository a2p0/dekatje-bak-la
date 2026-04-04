require "rails_helper"

RSpec.describe Subject, type: :model do
  describe "validations" do
    it "is valid with all required attributes and legacy files" do
      subject_obj = build(:subject)
      expect(subject_obj).to be_valid
    end

    it "is valid with new format files" do
      subject_obj = build(:subject, :new_format)
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

    context "conditional file validation" do
      it "requires correction_pdf when subject_pdf is attached" do
        subject_obj = build(:subject, :new_format)
        subject_obj.correction_pdf.detach
        # Force the blob to nil so attached? returns false
        subject_obj.correction_pdf = nil
        expect(subject_obj).not_to be_valid
        expect(subject_obj.errors[:correction_pdf]).to be_present
      end

      it "requires all 5 legacy files when enonce_file is attached" do
        subject_obj = build(:subject)
        subject_obj.dt_file = nil
        expect(subject_obj).not_to be_valid
        expect(subject_obj.errors[:dt_file]).to be_present
      end

      it "requires at least one format when no files attached" do
        subject_obj = build(:subject, :no_files)
        expect(subject_obj).not_to be_valid
        expect(subject_obj.errors[:base]).to be_present
      end
    end
  end

  describe "enums" do
    it "defines exam_type enum" do
      expect(Subject.exam_types).to eq("bac" => 0, "bts" => 1, "autre" => 2)
    end

    it "defines specialty enum with EE (was EC)" do
      expect(Subject.specialties).to eq(
        "tronc_commun" => 0, "SIN" => 1, "ITEC" => 2, "EE" => 3, "AC" => 4
      )
    end

    it "maps EE to integer 3" do
      expect(Subject.specialties["EE"]).to eq(3)
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

    it "optionally belongs to exam_session" do
      subject_obj = build(:subject, exam_session: nil)
      expect(subject_obj).to be_valid
    end

    it "can belong to an exam_session" do
      exam_session = create(:exam_session)
      subject_obj = create(:subject, exam_session: exam_session)
      expect(subject_obj.exam_session).to eq(exam_session)
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

  describe "#new_format?" do
    it "returns true when subject_pdf is attached" do
      subject_obj = build(:subject, :new_format)
      expect(subject_obj.new_format?).to be true
    end

    it "returns false when subject_pdf is not attached" do
      subject_obj = build(:subject)
      expect(subject_obj.new_format?).to be false
    end
  end

  describe "#effective_presentation_text" do
    it "returns exam_session presentation_text when present" do
      exam_session = create(:exam_session)
      exam_session.update!(presentation_text: "Session presentation")
      subject_obj = build(:subject, exam_session: exam_session, presentation_text: "Subject presentation")
      expect(subject_obj.effective_presentation_text).to eq("Session presentation")
    end

    it "falls back to own presentation_text when no exam_session" do
      subject_obj = build(:subject, exam_session: nil, presentation_text: "Subject presentation")
      expect(subject_obj.effective_presentation_text).to eq("Subject presentation")
    end

    it "falls back to own presentation_text when exam_session has no presentation_text" do
      exam_session = create(:exam_session)
      subject_obj = build(:subject, exam_session: exam_session, presentation_text: "Subject presentation")
      expect(subject_obj.effective_presentation_text).to eq("Subject presentation")
    end
  end

  describe "deletion behavior (FR-022)" do
    it "destroying a subject removes only its specific parts, not common parts" do
      exam_session = create(:exam_session)
      subject_obj = create(:subject, :new_format, exam_session: exam_session)

      common_part = create(:part,
        exam_session: exam_session, subject: nil,
        number: 1, title: "Commune", section_type: :common, position: 0)
      specific_part = create(:part,
        subject: subject_obj, exam_session: nil,
        number: 2, title: "Specifique", section_type: :specific, position: 1)

      subject_obj.destroy!

      expect(Part.find_by(id: specific_part.id)).to be_nil
      expect(Part.find_by(id: common_part.id)).to be_present
      expect(exam_session.reload.common_parts).to include(common_part)
    end
  end

  describe "ActiveStorage attachments" do
    context "legacy format" do
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

    context "new format" do
      it "has subject_pdf attached" do
        subject_obj = create(:subject, :new_format)
        expect(subject_obj.subject_pdf).to be_attached
      end

      it "has correction_pdf attached" do
        subject_obj = create(:subject, :new_format)
        expect(subject_obj.correction_pdf).to be_attached
      end
    end
  end
end
