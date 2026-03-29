# spec/models/student_insight_spec.rb
require "rails_helper"

RSpec.describe StudentInsight, type: :model do
  describe "associations" do
    it "belongs to student" do
      insight = build(:student_insight)
      expect(insight.student).to be_a(Student)
    end

    it "belongs to subject" do
      insight = build(:student_insight)
      expect(insight.subject).to be_a(Subject)
    end

    it "optionally belongs to question" do
      insight = build(:student_insight, question: nil)
      expect(insight).to be_valid
    end
  end

  describe "validations" do
    it "is valid with valid attributes" do
      insight = build(:student_insight)
      expect(insight).to be_valid
    end

    it "is invalid without concept" do
      insight = build(:student_insight, concept: nil)
      expect(insight).not_to be_valid
    end

    it "is invalid with unknown insight_type" do
      insight = build(:student_insight, insight_type: "unknown")
      expect(insight).not_to be_valid
    end

    %w[mastered struggle misconception note].each do |type|
      it "is valid with insight_type #{type}" do
        insight = build(:student_insight, insight_type: type)
        expect(insight).to be_valid
      end
    end
  end
end
