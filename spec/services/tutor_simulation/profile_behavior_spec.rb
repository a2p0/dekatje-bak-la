require "rails_helper"

RSpec.describe TutorSimulation::ProfileBehavior do
  describe ".for" do
    it "accepte un symbole" do
      expect { described_class.for(:autonome) }.not_to raise_error
    end

    it "accepte une string" do
      expect { described_class.for("autonome") }.not_to raise_error
    end

    it "lève KeyError sur profil inconnu" do
      expect { described_class.for(:inexistant) }.to raise_error(KeyError)
    end
  end

  describe "#should_view_correction?" do
    context "profil autonome" do
      let(:behavior) { described_class.for(:autonome) }

      it "retourne false même après 20 tours sans réussite" do
        expect(
          behavior.should_view_correction?(student_message: "encore raté", turns_without_correct: 20)
        ).to be(false)
      end

      it "retourne false même si le message contient [VOIR_CORRECTION]" do
        expect(
          behavior.should_view_correction?(student_message: "[VOIR_CORRECTION]", turns_without_correct: 0)
        ).to be(false)
      end
    end

    context "profil collaboratif" do
      let(:behavior) { described_class.for(:collaboratif) }

      it "retourne false avant 8 tours sans réussite" do
        expect(
          behavior.should_view_correction?(student_message: "j'essaie encore", turns_without_correct: 7)
        ).to be(false)
      end

      it "retourne true au 8e tour sans réussite" do
        expect(
          behavior.should_view_correction?(student_message: "je galère", turns_without_correct: 8)
        ).to be(true)
      end

      it "retourne true si message contient [VOIR_CORRECTION] avant 8 tours" do
        expect(
          behavior.should_view_correction?(student_message: "j'abandonne [VOIR_CORRECTION]", turns_without_correct: 2)
        ).to be(true)
      end

      it "retourne false si student_message est nil" do
        expect(
          behavior.should_view_correction?(student_message: nil, turns_without_correct: 0)
        ).to be(false)
      end
    end

    context "profil passif" do
      let(:behavior) { described_class.for(:passif) }

      it "retourne false avant 3 tours" do
        expect(
          behavior.should_view_correction?(student_message: "je sais pas", turns_without_correct: 2)
        ).to be(false)
      end

      it "retourne true au 3e tour sans réussite" do
        expect(
          behavior.should_view_correction?(student_message: "je sais pas", turns_without_correct: 3)
        ).to be(true)
      end

      it "retourne true si message contient [VOIR_CORRECTION]" do
        expect(
          behavior.should_view_correction?(student_message: "[VOIR_CORRECTION]", turns_without_correct: 0)
        ).to be(true)
      end
    end
  end

  describe "#strip_view_tag" do
    let(:behavior) { described_class.for(:passif) }

    it "retire le tag et trim le résultat" do
      expect(behavior.strip_view_tag("Bof. [VOIR_CORRECTION]")).to eq("Bof.")
    end

    it "retourne le message intact si pas de tag" do
      expect(behavior.strip_view_tag("je tente la formule v=d/t")).to eq("je tente la formule v=d/t")
    end

    it "retire toutes les occurrences" do
      expect(
        behavior.strip_view_tag("[VOIR_CORRECTION] ras-le-bol [VOIR_CORRECTION]")
      ).to eq("ras-le-bol")
    end

    it "retourne chaîne vide si message nil" do
      expect(behavior.strip_view_tag(nil)).to eq("")
    end
  end
end
