require "rails_helper"

RSpec.describe ResetStudentPassword do
  let(:classroom) { create(:classroom) }
  let(:student) { create(:student, classroom: classroom, password: "oldpassword") }

  describe ".call" do
    it "returns a new password" do
      result = described_class.call(student: student)
      expect(result).to be_present
      expect(result.length).to eq(8)
    end

    it "updates the student password" do
      result = described_class.call(student: student)
      student.reload
      expect(student.authenticate(result)).to eq(student)
    end

    it "invalidates the old password" do
      described_class.call(student: student)
      student.reload
      expect(student.authenticate("oldpassword")).to be_falsey
    end

    it "returns password with only unambiguous alphanumeric characters" do
      result = described_class.call(student: student)
      expect(result).to match(/\A[a-km-np-z2-9]+\z/)
    end
  end
end