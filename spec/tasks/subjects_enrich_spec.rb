require "rails_helper"
require "rake"

RSpec.describe "subjects:enrich_structured_correction", type: :task do
  let(:rake_task) { Rake::Task["subjects:enrich_structured_correction"] }

  let(:owner) { create(:user) }

  let(:success_result) { { enriched: 1, skipped: 0, errors: 0 } }
  let(:resolved_key) { ResolveApiKey::Result.new(api_key: "sk-test", provider: :anthropic) }

  before do
    Rails.application.load_tasks if Rake::Task.tasks.empty?
    rake_task.reenable
    allow(ResolveApiKey).to receive(:call).and_return(resolved_key)
    allow(EnrichAllAnswers).to receive(:call).and_return(success_result)
  end

  def build_subject_with_unenriched_answer(owner)
    subj     = create(:subject, owner: owner)
    part     = create(:part, subject: subj)
    question = create(:question, part: part)
    create(:answer, question: question, structured_correction: nil)
    subj
  end

  def build_subject_with_enriched_answer(owner)
    subj     = create(:subject, owner: owner)
    part     = create(:part, subject: subj)
    question = create(:question, part: part)
    create(:answer, question: question, structured_correction: { "input_data" => [], "final_answers" => [], "intermediate_steps" => [], "common_errors" => [] })
    subj
  end

  describe "with a specific subject_id" do
    context "when subject has 2 unenriched answers and 1 already enriched" do
      let!(:subject_obj) do
        subj     = create(:subject, owner: owner)
        part     = create(:part, subject: subj)
        q1       = create(:question, part: part, number: "1.1", position: 1)
        q2       = create(:question, part: part, number: "1.2", position: 2)
        q3       = create(:question, part: part, number: "1.3", position: 3)
        create(:answer, question: q1, structured_correction: nil)
        create(:answer, question: q2, structured_correction: nil)
        create(:answer, question: q3, structured_correction: { "input_data" => [] })
        subj
      end

      before do
        allow(EnrichAllAnswers).to receive(:call).and_return({ enriched: 2, skipped: 1, errors: 0 })
      end

      it "calls EnrichAllAnswers for that subject" do
        rake_task.invoke(subject_obj.id.to_s)
        expect(EnrichAllAnswers).to have_received(:call).with(
          subject: anything,
          api_key: "sk-test",
          provider: :anthropic
        )
      end

      it "calls ResolveApiKey with subject owner" do
        rake_task.invoke(subject_obj.id.to_s)
        expect(ResolveApiKey).to have_received(:call).with(user: subject_obj.owner)
      end
    end

    context "when subject does not exist" do
      it "raises ActiveRecord::RecordNotFound" do
        expect {
          rake_task.invoke("99999999")
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe "without argument (all subjects)" do
    let!(:subject_with_nil)     { build_subject_with_unenriched_answer(owner) }
    let!(:subject_already_done) { build_subject_with_enriched_answer(owner) }

    it "calls EnrichAllAnswers only for subjects with unenriched answers" do
      rake_task.invoke
      expect(EnrichAllAnswers).to have_received(:call).once
    end

    it "does not call EnrichAllAnswers for subjects where all answers are enriched" do
      rake_task.invoke
      expect(EnrichAllAnswers).to have_received(:call).with(
        subject: subject_with_nil,
        api_key: anything,
        provider: anything
      )
      expect(EnrichAllAnswers).not_to have_received(:call).with(
        subject: subject_already_done,
        api_key: anything,
        provider: anything
      )
    end
  end

  describe "output" do
    let!(:subject_obj) { build_subject_with_unenriched_answer(owner) }

    before do
      allow(EnrichAllAnswers).to receive(:call).and_return({ enriched: 1, skipped: 0, errors: 0 })
    end

    it "outputs the subject title and enrichment counts" do
      expect {
        rake_task.invoke(subject_obj.id.to_s)
      }.to output(/#{Regexp.escape(subject_obj.title)}/).to_stdout
    end
  end
end
