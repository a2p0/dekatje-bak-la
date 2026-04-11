require "rails_helper"

RSpec.describe Student::TutorHelper, type: :helper do
  describe "#task_type_options" do
    it "includes the correct type among options" do
      options = helper.task_type_options("calculation")
      values = options.map(&:first)
      expect(values).to include("calculation")
    end

    it "returns 4 options (1 correct + 3 distractors)" do
      options = helper.task_type_options("calculation")
      expect(options.size).to eq(4)
    end

    it "returns [value, label] pairs" do
      options = helper.task_type_options("calculation")
      options.each do |option|
        expect(option).to be_an(Array)
        expect(option.size).to eq(2)
        expect(Student::TutorHelper::TASK_TYPE_LABELS.keys).to include(option.first)
        expect(Student::TutorHelper::TASK_TYPE_LABELS.values).to include(option.last)
      end
    end

    it "shuffles the options" do
      results = 10.times.map { helper.task_type_options("calculation").map(&:first) }
      expect(results.uniq.size).to be > 1
    end
  end

  describe "#spotting_source_options" do
    let(:teacher) { create(:user) }
    let(:exam_session) { create(:exam_session, owner: teacher, common_presentation: "Présentation commune.") }

    context "with DT and DR attached" do
      let(:subject_record) { create(:subject, owner: teacher, exam_session: exam_session) }

      it "includes DT option" do
        options = helper.spotting_source_options(subject_record)
        expect(options).to include([ "dt", "Document Technique (DT)" ])
      end

      it "includes DR option" do
        options = helper.spotting_source_options(subject_record)
        expect(options).to include([ "dr", "Document Réponse (DR)" ])
      end

      it "always includes énoncé option" do
        options = helper.spotting_source_options(subject_record)
        expect(options).to include([ "enonce", "Énoncé de la question" ])
      end

      it "includes mise en situation when common_presentation present" do
        options = helper.spotting_source_options(subject_record)
        expect(options).to include([ "mise_en_situation", "Mise en situation" ])
      end
    end

    context "without DT/DR attached (new format)" do
      let(:subject_record) { create(:subject, :new_format, owner: teacher, exam_session: exam_session) }

      it "does not include DT option" do
        options = helper.spotting_source_options(subject_record)
        expect(options).not_to include([ "dt", "Document Technique (DT)" ])
      end

      it "does not include DR option" do
        options = helper.spotting_source_options(subject_record)
        expect(options).not_to include([ "dr", "Document Réponse (DR)" ])
      end

      it "still includes énoncé" do
        options = helper.spotting_source_options(subject_record)
        expect(options).to include([ "enonce", "Énoncé de la question" ])
      end
    end

    context "without common_presentation" do
      let(:exam_session_no_pres) { create(:exam_session, owner: teacher, common_presentation: nil) }
      let(:subject_record) { create(:subject, owner: teacher, exam_session: exam_session_no_pres) }

      it "does not include mise en situation" do
        options = helper.spotting_source_options(subject_record)
        expect(options).not_to include([ "mise_en_situation", "Mise en situation" ])
      end
    end
  end
end
