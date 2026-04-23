require "rails_helper"

RSpec.describe PersistExtractedData do
  let(:exam_session) { create(:exam_session) }
  let(:subject_obj) { create(:subject, :new_format, exam_session: exam_session) }

  let(:data) do
    {
      "metadata" => {
        "title" => "CIME", "year" => "2024", "specialty" => "ITEC",
        "code" => "24-2D2IDACPO1", "exam" => "bac",
        "region" => "polynesie", "variante" => "normale"
      },
      "common_presentation" => "Mise en situation...",
      "specific_presentation" => "Contexte spécifique ITEC...",
      "common_parts" => [
        {
          "number" => 1, "title" => "Partie 1", "objective" => "Objectif...",
          "questions" => [
            { "number" => "1.1", "label" => "Calculer...", "context" => "", "points" => 2,
              "answer_type" => "calculation", "dt_references" => [ "DT1" ],
              "dr_references" => [], "correction" => "Result...",
              "explanation" => "...", "key_concepts" => [ "energy" ], "data_hints" => [] }
          ]
        }
      ],
      "specific_parts" => [
        {
          "number" => "A", "title" => "Partie A", "objective" => "...",
          "questions" => [
            { "number" => "A.1", "label" => "Relever...", "context" => "", "points" => 3,
              "answer_type" => "text", "dt_references" => [ "DTS1" ],
              "dr_references" => [ "DRS1" ], "correction" => "...",
              "explanation" => "...", "key_concepts" => [], "data_hints" => [] }
          ]
        }
      ],
      "document_references" => {
        "common_dts" => [ { "label" => "DT1", "title" => "Diagrammes", "pages" => [ 13 ] } ],
        "common_drs" => [ { "label" => "DR1", "title" => "Tableau", "pages" => [ 22 ] } ],
        "specific_dts" => [ { "label" => "DTS1", "title" => "Norme", "pages" => [ 30 ] } ],
        "specific_drs" => [ { "label" => "DRS1", "title" => "Sollicitations", "pages" => [ 34 ] } ]
      }
    }
  end

  describe ".call" do
    context "first upload (no existing common parts)" do
      it "sets exam_session common_presentation from data" do
        described_class.call(subject: subject_obj, data: data)
        expect(exam_session.reload.common_presentation).to eq("Mise en situation...")
      end

      it "sets subject specific_presentation from data" do
        described_class.call(subject: subject_obj, data: data)
        expect(subject_obj.reload.specific_presentation).to eq("Contexte spécifique ITEC...")
      end

      it "sets subject code from metadata" do
        described_class.call(subject: subject_obj, data: data)
        expect(subject_obj.reload.code).to eq("24-2D2IDACPO1")
      end

      it "sets exam_session variante from metadata" do
        described_class.call(subject: subject_obj, data: data)
        expect(exam_session.reload.variante).to eq("normale")
      end

      it "sets exam_session exam from metadata" do
        data["metadata"]["exam"] = "bts"
        described_class.call(subject: subject_obj, data: data)
        expect(exam_session.reload.exam).to eq("bts")
      end

      it "creates common parts on exam_session (not on subject)" do
        described_class.call(subject: subject_obj, data: data)

        common_parts = exam_session.reload.common_parts
        expect(common_parts.count).to eq(1)

        part = common_parts.first
        expect(part.number).to eq("1")
        expect(part.title).to eq("Partie 1")
        expect(part.objective_text).to eq("Objectif...")
        expect(part.section_type).to eq("common")
        expect(part.subject_id).to be_nil
      end

      it "creates specific parts on subject (not on exam_session)" do
        described_class.call(subject: subject_obj, data: data)

        specific_parts = subject_obj.reload.parts.where(section_type: :specific)
        expect(specific_parts.count).to eq(1)

        part = specific_parts.first
        expect(part.title).to eq("Partie A")
        expect(part.section_type).to eq("specific")
        expect(part.exam_session_id).to be_nil
      end

      it "creates questions with dt_references and dr_references" do
        described_class.call(subject: subject_obj, data: data)

        common_question = exam_session.common_parts.first.questions.first
        expect(common_question.number).to eq("1.1")
        expect(common_question.label).to eq("Calculer...")
        expect(common_question.points).to eq(2.0)
        expect(common_question.answer_type).to eq("calculation")
        expect(common_question.dt_references).to eq([ "DT1" ])
        expect(common_question.dr_references).to eq([])

        specific_question = subject_obj.parts.where(section_type: :specific).first.questions.first
        expect(specific_question.number).to eq("A.1")
        expect(specific_question.label).to eq("Relever...")
        expect(specific_question.points).to eq(3.0)
        expect(specific_question.answer_type).to eq("text")
        expect(specific_question.dt_references).to eq([ "DTS1" ])
        expect(specific_question.dr_references).to eq([ "DRS1" ])
      end

      it "creates answers with correction_text, explanation_text, key_concepts, and data_hints" do
        described_class.call(subject: subject_obj, data: data)

        common_answer = exam_session.common_parts.first.questions.first.answer
        expect(common_answer.correction_text).to eq("Result...")
        expect(common_answer.explanation_text).to eq("...")
        expect(common_answer.key_concepts).to eq([ "energy" ])
        expect(common_answer.data_hints).to eq([])

        specific_answer = subject_obj.parts.where(section_type: :specific).first.questions.first.answer
        expect(specific_answer.correction_text).to eq("...")
        expect(specific_answer.explanation_text).to eq("...")
        expect(specific_answer.key_concepts).to eq([])
        expect(specific_answer.data_hints).to eq([])
      end

      it "stores document_references on common parts" do
        described_class.call(subject: subject_obj, data: data)

        common_part = exam_session.common_parts.first
        expect(common_part.document_references).to include(
          { "label" => "DT1", "title" => "Diagrammes", "pages" => [ 13 ] },
          { "label" => "DR1", "title" => "Tableau", "pages" => [ 22 ] }
        )
      end

      it "stores document_references on specific parts" do
        described_class.call(subject: subject_obj, data: data)

        specific_part = subject_obj.parts.where(section_type: :specific).first
        expect(specific_part.document_references).to include(
          { "label" => "DTS1", "title" => "Norme", "pages" => [ 30 ] },
          { "label" => "DRS1", "title" => "Sollicitations", "pages" => [ 34 ] }
        )
      end

      it "updates subject status to pending_validation" do
        described_class.call(subject: subject_obj, data: data)
        expect(subject_obj.reload.status).to eq("pending_validation")
      end

      it "creates the expected total number of parts, questions, and answers" do
        expect {
          described_class.call(subject: subject_obj, data: data)
        }.to change(Part, :count).by(2)
          .and change(Question, :count).by(2)
          .and change(Answer, :count).by(2)
      end
    end

    context "second upload (common parts already exist on exam_session)" do
      before do
        # Simulate first upload already completed: common parts exist
        exam_session.update!(common_presentation: "Mise en situation...")
        common_part = exam_session.common_parts.create!(
          number: 1, title: "Partie 1", objective_text: "Objectif...",
          section_type: :common, position: 0, document_references: [
            { "label" => "DT1", "title" => "Diagrammes", "pages" => [ 13 ] },
            { "label" => "DR1", "title" => "Tableau", "pages" => [ 22 ] }
          ]
        )
        question = common_part.questions.create!(
          number: "1.1", label: "Calculer...", context_text: "",
          points: 2, answer_type: :calculation, position: 0, status: :draft,
          dt_references: [ "DT1" ], dr_references: []
        )
        question.create_answer!(
          correction_text: "Result...", explanation_text: "...",
          key_concepts: [ "energy" ], data_hints: []
        )
      end

      it "does NOT recreate common parts" do
        expect {
          described_class.call(subject: subject_obj, data: data)
        }.not_to change { exam_session.common_parts.count }
      end

      it "preserves existing common parts" do
        described_class.call(subject: subject_obj, data: data)

        expect(exam_session.common_parts.count).to eq(1)
        expect(exam_session.common_parts.first.title).to eq("Partie 1")
      end

      it "only creates specific parts for the new specialty" do
        expect {
          described_class.call(subject: subject_obj, data: data)
        }.to change { subject_obj.parts.where(section_type: :specific).count }.by(1)
      end

      it "still updates subject status to pending_validation" do
        described_class.call(subject: subject_obj, data: data)
        expect(subject_obj.reload.status).to eq("pending_validation")
      end
    end

    context "transaction rollback on error" do
      let(:bad_data) do
        {
          "metadata" => { "title" => "CIME", "year" => "2024", "specialty" => "ITEC" },
          "common_presentation" => "Mise en situation...",
          "common_parts" => [
            {
              "number" => 1, "title" => "Partie 1", "objective" => "Objectif...",
              "questions" => [
                { "number" => nil, "label" => nil, "context" => "", "points" => 2,
                  "answer_type" => "calculation", "dt_references" => [],
                  "dr_references" => [], "correction" => "...",
                  "explanation" => "...", "key_concepts" => [], "data_hints" => [] }
              ]
            }
          ],
          "specific_parts" => [],
          "document_references" => {}
        }
      end

      it "rolls back all changes when an error occurs" do
        expect {
          described_class.call(subject: subject_obj, data: bad_data) rescue nil
        }.not_to change(Part, :count)
      end

      it "does not update subject status on failure" do
        described_class.call(subject: subject_obj, data: bad_data) rescue nil
        expect(subject_obj.reload.status).to eq("draft")
      end

      it "does not update exam_session common_presentation on failure" do
        described_class.call(subject: subject_obj, data: bad_data) rescue nil
        expect(exam_session.reload.common_presentation).to be_nil
      end
    end

    context "idempotence (retry after partial failure)" do
      it "does not create duplicate specific parts when called twice" do
        described_class.call(subject: subject_obj, data: data)
        first_count = subject_obj.parts.specific.count
        expect(first_count).to be > 0

        described_class.call(subject: subject_obj, data: data)
        expect(subject_obj.parts.specific.count).to eq(first_count)
      end

      it "preserves common parts (shared via exam_session) across retries" do
        described_class.call(subject: subject_obj, data: data)
        common_ids_before = exam_session.reload.common_parts.pluck(:id).sort
        expect(common_ids_before).not_to be_empty

        described_class.call(subject: subject_obj, data: data)
        common_ids_after = exam_session.reload.common_parts.pluck(:id).sort
        expect(common_ids_after).to eq(common_ids_before)
      end
    end
  end
end
