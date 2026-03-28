class PersistExtractedData
  def self.call(subject:, data:)
    ActiveRecord::Base.transaction do
      subject.update!(
        presentation_text: data["presentation"],
        status: :pending_validation
      )

      Array(data["parts"]).each_with_index do |part_data, part_index|
        part = subject.parts.create!(
          number:         part_data["number"].to_i,
          title:          part_data["title"].to_s,
          objective_text: part_data["objective"].to_s,
          section_type:   part_data["section_type"] || "common",
          position:       part_index
        )

        Array(part_data["questions"]).each_with_index do |q_data, q_index|
          question = part.questions.create!(
            number:       q_data["number"].to_s,
            label:        q_data["label"].to_s,
            context_text: q_data["context"].to_s,
            points:       q_data["points"].to_f,
            answer_type:  q_data["answer_type"] || "text",
            position:     q_index,
            status:       :draft
          )

          question.create_answer!(
            correction_text:  q_data["correction"].to_s,
            explanation_text: q_data["explanation"].to_s,
            key_concepts:     Array(q_data["key_concepts"]),
            data_hints:       Array(q_data["data_hints"])
          )
        end
      end
    end

    subject
  end
end
