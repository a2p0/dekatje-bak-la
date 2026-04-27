require "rails_helper"

RSpec.describe MapExtractedMetadata do
  subject(:service) { described_class }

  def call(raw_json)
    service.call(raw_json)
  end

  let(:full_raw_json) do
    JSON.generate({
      "metadata" => {
        "title"    => "Complexe International Multisports",
        "year"     => "2024",
        "exam"     => "bac",
        "specialty" => "AC",
        "region"   => "metropole",
        "variante" => "normale"
      }
    })
  end

  describe "with complete valid metadata" do
    it "returns all 6 fields" do
      result = call(full_raw_json)
      expect(result).to include(
        title:    "Complexe International Multisports",
        year:     "2024",
        exam:     "bac",
        specialty: "ac",
        region:   "metropole",
        variante: "normale"
      )
    end
  end

  describe "case normalization" do
    it "downcases specialty values" do
      raw = JSON.generate({ "metadata" => { "specialty" => "SIN" } })
      expect(call(raw)[:specialty]).to eq("sin")
    end

    it "downcases exam values" do
      raw = JSON.generate({ "metadata" => { "exam" => "BAC" } })
      expect(call(raw)[:exam]).to eq("bac")
    end

    it "strips whitespace from string fields" do
      raw = JSON.generate({ "metadata" => { "title" => "  My Title  " } })
      expect(call(raw)[:title]).to eq("My Title")
    end
  end

  describe "invalid enum values → nil" do
    it "returns nil for unknown specialty" do
      raw = JSON.generate({ "metadata" => { "specialty" => "unknown_specialty" } })
      expect(call(raw)[:specialty]).to be_nil
    end

    it "returns nil for unknown exam" do
      raw = JSON.generate({ "metadata" => { "exam" => "licence" } })
      expect(call(raw)[:exam]).to be_nil
    end

    it "returns nil for unknown region" do
      raw = JSON.generate({ "metadata" => { "region" => "paris" } })
      expect(call(raw)[:region]).to be_nil
    end

    it "returns nil for unknown variante" do
      raw = JSON.generate({ "metadata" => { "variante" => "special" } })
      expect(call(raw)[:variante]).to be_nil
    end
  end

  describe "nil / missing input" do
    it "returns all-nil hash when raw_json is nil" do
      result = call(nil)
      expect(result).to eq({ title: nil, year: nil, exam: nil, specialty: nil, region: nil, variante: nil })
    end

    it "returns all-nil hash when metadata key is absent" do
      raw = JSON.generate({ "parts" => [] })
      result = call(raw)
      expect(result).to eq({ title: nil, year: nil, exam: nil, specialty: nil, region: nil, variante: nil })
    end

    it "returns nil for empty string title" do
      raw = JSON.generate({ "metadata" => { "title" => "" } })
      expect(call(raw)[:title]).to be_nil
    end
  end

  describe "raw_json wrapped in markdown fences (as stored in DB)" do
    it "handles json wrapped in ```json fences" do
      raw = "```json\n#{JSON.generate({ 'metadata' => { 'exam' => 'bts' } })}\n```"
      expect(call(raw)[:exam]).to eq("bts")
    end
  end

  describe "all valid specialty values" do
    %w[sin itec ee ac].each do |val|
      it "accepts #{val}" do
        raw = JSON.generate({ "metadata" => { "specialty" => val } })
        expect(call(raw)[:specialty]).to eq(val)
      end
    end
  end

  describe "all valid exam values" do
    %w[bac bts autre].each do |val|
      it "accepts #{val}" do
        raw = JSON.generate({ "metadata" => { "exam" => val } })
        expect(call(raw)[:exam]).to eq(val)
      end
    end
  end

  describe "all valid region values" do
    %w[metropole reunion polynesie candidat_libre].each do |val|
      it "accepts #{val}" do
        raw = JSON.generate({ "metadata" => { "region" => val } })
        expect(call(raw)[:region]).to eq(val)
      end
    end
  end
end
