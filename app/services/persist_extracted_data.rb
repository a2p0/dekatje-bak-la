class PersistExtractedData
  def self.call(subject:, data:)
    ActiveRecord::Base.transaction do
      exam_session = subject.exam_session

      if exam_session.presentation_text.blank?
        exam_session.update!(presentation_text: data["presentation"])
      end

      subject.update!(status: :pending_validation)

      # Common parts: only create if exam_session has none yet
      unless exam_session.common_parts.any?
        common_doc_refs = Array(data.dig("document_references", "common_dts")) +
                          Array(data.dig("document_references", "common_drs"))

        Array(data["common_parts"]).each_with_index do |part_data, idx|
          part = exam_session.common_parts.create!(
            number:               part_data["number"].to_i,
            title:                part_data["title"].to_s,
            objective_text:       part_data["objective"].to_s,
            section_type:         :common,
            position:             idx,
            document_references:  common_doc_refs
          )

          create_questions_and_answers(part, part_data["questions"])
        end
      end

      # Specific parts: always create on subject
      specific_doc_refs = Array(data.dig("document_references", "specific_dts")) +
                          Array(data.dig("document_references", "specific_drs"))

      Array(data["specific_parts"]).each_with_index do |part_data, idx|
        part = subject.parts.create!(
          number:               part_data["number"].to_i,
          title:                part_data["title"].to_s,
          objective_text:       part_data["objective"].to_s,
          section_type:         :specific,
          specialty:            subject.specialty,
          position:             idx,
          document_references:  specific_doc_refs
        )

        create_questions_and_answers(part, part_data["questions"])
      end
    end

    subject
  end

  def self.create_questions_and_answers(part, questions_data)
    Array(questions_data).each_with_index do |q_data, q_index|
      question = part.questions.create!(
        number:        q_data["number"].to_s,
        label:         q_data["label"].to_s,
        context_text:  q_data["context"].to_s,
        points:        q_data["points"].to_f,
        answer_type:   q_data["answer_type"] || "text",
        position:      q_index,
        status:        :draft,
        dt_references: Array(q_data["dt_references"]),
        dr_references: Array(q_data["dr_references"])
      )

      question.create_answer!(
        correction_text:  q_data["correction"].to_s,
        explanation_text: q_data["explanation"].to_s,
        key_concepts:     Array(q_data["key_concepts"]),
        data_hints:       Array(q_data["data_hints"])
      )
    end
  end

  private_class_method :create_questions_and_answers
end
