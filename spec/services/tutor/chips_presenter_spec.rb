require "rails_helper"

RSpec.describe Tutor::ChipsPresenter do
  def chips(phase:, hints_used: 0)
    described_class.call(phase: phase, hints_used: hints_used)
  end

  describe "idle / no conversation" do
    it "returns empty array" do
      expect(chips(phase: "idle")).to eq([])
    end
  end

  describe "greeting / enonce" do
    %w[greeting enonce].each do |phase|
      context "phase=#{phase}" do
        subject { chips(phase: phase) }
        it "has 2 chips: Reformule + Définis" do
          expect(subject.map { _1[:label] }).to eq(["Reformule la question", "Définis un terme"])
        end
        it "all chips are :send action" do
          expect(subject.map { _1[:action] }).to all(eq(:send))
        end
        it "Reformule uses teal color" do
          expect(subject[0][:color]).to eq(:teal)
        end
        it "Définis uses red color" do
          expect(subject[1][:color]).to eq(:red)
        end
      end
    end
  end

  describe "spotting_type / spotting_data" do
    %w[spotting_type spotting_data].each do |phase|
      context "phase=#{phase}" do
        subject { chips(phase: phase) }
        it "has 2 chips: Donne un exemple + Reformule" do
          expect(subject.map { _1[:label] }).to eq(["Donne un exemple", "Reformule la question"])
        end
        it "Donne un exemple uses yellow color" do
          expect(subject[0][:color]).to eq(:yellow)
        end
      end
    end
  end

  describe "guiding" do
    context "hints_used < 5" do
      subject { chips(phase: "guiding", hints_used: 2) }
      it "has 3 chips: Un indice + Reformule + Définis" do
        expect(subject.map { _1[:label] }).to eq(["Un indice", "Reformule", "Définis"])
      end
      it "Un indice is not disabled" do
        expect(subject[0][:disabled]).to be_falsey
      end
      it "Un indice uses yellow color" do
        expect(subject[0][:color]).to eq(:yellow)
      end
    end

    context "hints_used = 5 (MAX_HINTS)" do
      subject { chips(phase: "guiding", hints_used: 5) }
      it "has 3 chips including disabled Un indice last" do
        expect(subject.map { _1[:label] }).to eq(["Reformule", "Définis", "Un indice"])
      end
      it "Un indice is disabled" do
        hint_chip = subject.find { _1[:label] == "Un indice" }
        expect(hint_chip[:disabled]).to be_truthy
      end
    end

    context "hints_used > 5 (above MAX_HINTS)" do
      subject { chips(phase: "guiding", hints_used: 7) }
      it "Un indice is disabled" do
        hint_chip = subject.find { _1[:label] == "Un indice" }
        expect(hint_chip[:disabled]).to be_truthy
      end
    end
  end

  describe "validating" do
    subject { chips(phase: "validating") }
    it "has 5 confidence chips" do
      expect(subject.size).to eq(5)
    end
    it "all chips are :confidence action" do
      expect(subject.map { _1[:action] }).to all(eq(:confidence))
    end
    it "levels are 1..5" do
      expect(subject.map { _1[:level] }).to eq([1, 2, 3, 4, 5])
    end
    it "labels include emojis" do
      expect(subject[0][:label]).to include("😰")
      expect(subject[4][:label]).to include("💪")
    end
  end

  describe "feedback / ended" do
    %w[feedback ended].each do |phase|
      context "phase=#{phase}" do
        subject { chips(phase: phase) }
        it "has Explique la correction chip (send)" do
          chip = subject.find { _1[:label] == "Explique la correction" }
          expect(chip).to be_present
          expect(chip[:action]).to eq(:send)
        end
        it "has Question suivante chip (navigate)" do
          chip = subject.find { _1[:action] == :navigate }
          expect(chip).to be_present
          expect(chip[:label]).to include("suivante")
        end
      end
    end
  end
end
