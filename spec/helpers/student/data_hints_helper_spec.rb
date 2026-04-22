require "rails_helper"

RSpec.describe Student::DataHintsHelper, type: :helper do
  describe "#hint_source_label" do
    it "translates question_context to Contexte" do
      expect(helper.hint_source_label("question_context")).to eq("Contexte")
    end

    it "translates mise_en_situation to Présentation" do
      expect(helper.hint_source_label("mise_en_situation")).to eq("Présentation")
    end

    it "translates enonce to Énoncé" do
      expect(helper.hint_source_label("enonce")).to eq("Énoncé")
    end

    it "translates tableau_sujet to Tableau du sujet" do
      expect(helper.hint_source_label("tableau_sujet")).to eq("Tableau du sujet")
    end

    it "keeps DT references as-is" do
      expect(helper.hint_source_label("DT1")).to eq("DT1")
      expect(helper.hint_source_label("DT2")).to eq("DT2")
    end

    it "keeps DR references as-is" do
      expect(helper.hint_source_label("DR1")).to eq("DR1")
    end

    it "returns the raw source as fallback for unknown keys" do
      expect(helper.hint_source_label("unknown_source")).to eq("unknown_source")
    end
  end

  describe "#hint_badge_color" do
    it "returns :blue for DT sources" do
      expect(helper.hint_badge_color("DT1")).to eq(:blue)
      expect(helper.hint_badge_color("DT2")).to eq(:blue)
      expect(helper.hint_badge_color("DT")).to eq(:blue)
    end

    it "returns :amber for DR sources" do
      expect(helper.hint_badge_color("DR1")).to eq(:amber)
      expect(helper.hint_badge_color("DR")).to eq(:amber)
    end

    it "returns :slate for other sources" do
      expect(helper.hint_badge_color("question_context")).to eq(:slate)
      expect(helper.hint_badge_color("mise_en_situation")).to eq(:slate)
      expect(helper.hint_badge_color("enonce")).to eq(:slate)
    end
  end
end