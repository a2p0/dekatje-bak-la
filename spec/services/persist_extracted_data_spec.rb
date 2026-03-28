require "rails_helper"

RSpec.describe PersistExtractedData do
  let(:subject_obj) { create(:subject) }

  let(:data) do
    {
      "presentation" => "Mise en situation du sujet CIME.",
      "parts" => [
        {
          "number" => 1,
          "title" => "Comment le CIME s'inscrit dans une démarche DD ?",
          "objective" => "Comparer les modes de transport",
          "section_type" => "common",
          "questions" => [
            {
              "number" => "1.1",
              "label" => "Calculer la consommation en litres pour 186 km.",
              "context" => "Données : distance = 186 km",
              "points" => 2,
              "answer_type" => "calculation",
              "correction" => "Car = 56,73 l",
              "explanation" => "On applique : Conso × Distance / 100",
              "data_hints" => [ { "source" => "DT", "location" => "tableau Consommation" } ],
              "key_concepts" => [ "énergie primaire" ]
            }
          ]
        }
      ]
    }
  end

  describe ".call" do
    it "updates subject presentation_text" do
      described_class.call(subject: subject_obj, data: data)
      expect(subject_obj.reload.presentation_text).to eq("Mise en situation du sujet CIME.")
    end

    it "sets subject status to pending_validation" do
      described_class.call(subject: subject_obj, data: data)
      expect(subject_obj.reload.status).to eq("pending_validation")
    end

    it "creates parts" do
      expect {
        described_class.call(subject: subject_obj, data: data)
      }.to change(Part, :count).by(1)
    end

    it "creates questions" do
      expect {
        described_class.call(subject: subject_obj, data: data)
      }.to change(Question, :count).by(1)
    end

    it "creates answers" do
      expect {
        described_class.call(subject: subject_obj, data: data)
      }.to change(Answer, :count).by(1)
    end

    it "sets correct part attributes" do
      described_class.call(subject: subject_obj, data: data)
      part = subject_obj.reload.parts.first
      expect(part.number).to eq(1)
      expect(part.title).to eq("Comment le CIME s'inscrit dans une démarche DD ?")
      expect(part.section_type).to eq("common")
    end

    it "sets correct question attributes" do
      described_class.call(subject: subject_obj, data: data)
      question = subject_obj.parts.first.questions.first
      expect(question.number).to eq("1.1")
      expect(question.answer_type).to eq("calculation")
      expect(question.points).to eq(2.0)
    end

    it "sets correct answer attributes with data_hints" do
      described_class.call(subject: subject_obj, data: data)
      answer = subject_obj.parts.first.questions.first.answer
      expect(answer.correction_text).to eq("Car = 56,73 l")
      expect(answer.data_hints).to eq([ { "source" => "DT", "location" => "tableau Consommation" } ])
      expect(answer.key_concepts).to eq([ "énergie primaire" ])
    end

    it "rolls back on error" do
      bad_data = { "presentation" => "test", "parts" => [ { "number" => nil, "title" => nil, "section_type" => "common", "questions" => [] } ] }
      expect {
        described_class.call(subject: subject_obj, data: bad_data) rescue nil
      }.not_to change(Part, :count)
    end
  end
end
