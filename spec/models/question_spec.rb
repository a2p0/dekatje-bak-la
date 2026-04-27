require "rails_helper"

RSpec.describe Question, type: :model do
  describe "validations" do
    it "is valid with required attributes" do
      question = build(:question)
      expect(question).to be_valid
    end

    it "requires number" do
      question = build(:question, number: nil)
      expect(question).not_to be_valid
    end

    it "requires label" do
      question = build(:question, label: nil)
      expect(question).not_to be_valid
    end
  end

  describe "enums" do
    it "defines the 7 new answer_type values (049)" do
      expect(Question.answer_types).to eq(
        "identification" => 0,
        "calcul"         => 1,
        "justification"  => 2,
        "representation" => 3,
        "qcm"            => 4,
        "verification"   => 5,
        "conclusion"     => 6
      )
    end

    it "does not include old answer_type values" do
      old_types = %w[text calculation argumentation dr_reference completion choice]
      old_types.each do |old|
        expect(Question.answer_types).not_to have_key(old)
      end
    end

    it "defines status enum with draft as default" do
      question = build(:question)
      expect(question.status).to eq("draft")
    end
  end

  describe "scopes" do
    it "kept excludes soft-deleted questions" do
      kept = create(:question)
      deleted = create(:question, discarded_at: Time.current)
      expect(Question.kept).to include(kept)
      expect(Question.kept).not_to include(deleted)
    end
  end

  describe "associations" do
    it "belongs to part" do
      question = build(:question)
      expect(question.part).to be_a(Part)
    end
  end

  describe "#validate!" do
    let(:question) { create(:question, status: :draft) }

    it "transitions from draft to validated" do
      question.validate!
      expect(question.reload.status).to eq("validated")
    end

    it "raises InvalidTransition when already validated" do
      question.update!(status: :validated)
      expect { question.validate! }.to raise_error(Question::InvalidTransition, /déjà validée/)
    end
  end

  describe "#invalidate!" do
    let(:question) { create(:question, status: :validated) }

    it "transitions from validated to draft" do
      question.invalidate!
      expect(question.reload.status).to eq("draft")
    end

    it "raises InvalidTransition when already draft" do
      question.update!(status: :draft)
      expect { question.invalidate! }.to raise_error(Question::InvalidTransition, /brouillon/)
    end
  end
end
