require "rails_helper"

RSpec.describe SubjectAccessPolicy do
  let(:classroom_ac) { build(:classroom, :ac) }
  let(:classroom_ee) { build(:classroom, :ee) }
  let(:classroom_sin) { build(:classroom, :sin) }

  let(:subject_ac)  { build(:subject, :ac, :no_files) }
  let(:subject_ee)  { build(:subject, :ee, :no_files) }
  let(:subject_tc)  { build(:subject, :tronc_commun, :no_files) }

  describe ".full_access?" do
    it "returns true when classroom and subject specialties match" do
      expect(described_class.full_access?(subject_ac, classroom_ac)).to be true
    end

    it "returns false when classroom and subject specialties differ" do
      expect(described_class.full_access?(subject_ac, classroom_ee)).to be false
    end

    it "returns false for tronc_commun subject regardless of classroom specialty" do
      expect(described_class.full_access?(subject_tc, classroom_ac)).to be false
      expect(described_class.full_access?(subject_tc, classroom_ee)).to be false
    end

    it "handles case-insensitive comparison (subject 'SIN' vs classroom 'sin')" do
      classroom = build(:classroom, specialty: "sin")
      subject   = build(:subject, :sin, :no_files)
      expect(described_class.full_access?(subject, classroom)).to be true
    end
  end

  describe ".tc_only?" do
    it "returns false when full access is granted" do
      expect(described_class.tc_only?(subject_ac, classroom_ac)).to be false
    end

    it "returns true when specialties differ" do
      expect(described_class.tc_only?(subject_ac, classroom_ee)).to be true
    end

    it "returns true for tronc_commun subject" do
      expect(described_class.tc_only?(subject_tc, classroom_ac)).to be true
    end
  end

  describe ".accessible_parts" do
    let(:common_part)   { build(:part, section_type: :common) }
    let(:specific_part) { build(:part, section_type: :specific) }
    let(:all_parts)     { [ common_part, specific_part ] }

    context "when full access (matching specialty)" do
      it "returns all parts" do
        result = described_class.accessible_parts(all_parts, subject_ac, classroom_ac)
        expect(result).to contain_exactly(common_part, specific_part)
      end
    end

    context "when tc_only (different specialty)" do
      it "returns only common parts" do
        result = described_class.accessible_parts(all_parts, subject_ac, classroom_ee)
        expect(result).to contain_exactly(common_part)
      end
    end

    context "when tc_only (tronc_commun subject)" do
      it "returns only common parts" do
        result = described_class.accessible_parts(all_parts, subject_tc, classroom_ac)
        expect(result).to contain_exactly(common_part)
      end
    end

    context "when subject has only common parts" do
      it "returns all parts regardless of specialty" do
        common_parts_only = [ common_part ]
        result = described_class.accessible_parts(common_parts_only, subject_ee, classroom_ac)
        expect(result).to contain_exactly(common_part)
      end
    end
  end
end
