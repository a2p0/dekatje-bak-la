require "rails_helper"

RSpec.describe Tutor::Result do
  describe ".ok" do
    it "builds a successful result with a value" do
      r = described_class.ok(foo: "bar")
      expect(r.ok?).to be true
      expect(r.err?).to be false
      expect(r.value).to eq(foo: "bar")
      expect(r.error).to be_nil
    end

    it "builds a successful result with no value" do
      r = described_class.ok
      expect(r.ok?).to be true
      expect(r.value).to be_nil
    end
  end

  describe ".err" do
    it "builds a failed result with an error message" do
      r = described_class.err("Something went wrong")
      expect(r.ok?).to be false
      expect(r.err?).to be true
      expect(r.error).to eq("Something went wrong")
      expect(r.value).to be_nil
    end
  end
end