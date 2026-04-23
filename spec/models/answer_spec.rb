require "rails_helper"

RSpec.describe Answer, type: :model do
  describe "associations" do
    it "belongs to question" do
      answer = build(:answer)
      expect(answer.question).to be_a(Question)
    end
  end

  describe "jsonb fields" do
    it "stores key_concepts as array" do
      answer = create(:answer, key_concepts: [ "rendement", "puissance" ])
      answer.reload
      expect(answer.key_concepts).to eq([ "rendement", "puissance" ])
    end

    it "stores data_hints as array of hashes" do
      hints = [ { "source" => "DT", "location" => "tableau ligne 3" } ]
      answer = create(:answer, data_hints: hints)
      answer.reload
      expect(answer.data_hints).to eq(hints)
    end
  end
end
