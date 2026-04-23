require "rails_helper"

RSpec.describe ClassroomSubject, type: :model do
  describe "associations" do
    it "belongs to classroom" do
      cs = build(:classroom_subject)
      expect(cs.classroom).to be_a(Classroom)
    end

    it "belongs to subject" do
      cs = build(:classroom_subject)
      expect(cs.subject).to be_a(Subject)
    end
  end

  describe "uniqueness" do
    it "prevents duplicate classroom-subject pairs" do
      classroom = create(:classroom)
      subject = create(:subject)
      create(:classroom_subject, classroom: classroom, subject: subject)
      duplicate = build(:classroom_subject, classroom: classroom, subject: subject)
      expect(duplicate).not_to be_valid
    end
  end
end
