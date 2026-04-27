class PersistExtractedData
  ANSWER_TYPE_LEGACY_MAP = {
    "text"          => "identification",
    "calculation"   => "calcul",
    "argumentation" => "justification",
    "dr_reference"  => "representation",
    "completion"    => "representation",
    "choice"        => "qcm"
  }.freeze

  def self.call(subject:, data:) = new(subject:, data:).call

  def initialize(subject:, data:)
    @subject = subject
    @data = data
  end

  def call
    ActiveRecord::Base.transaction do
      exam_session = @subject.exam_session

      if exam_session.common_presentation.blank?
        exam_session.update!(common_presentation: @data["common_presentation"])
      end

      if @subject.specific_presentation.blank? && @data["specific_presentation"].present?
        @subject.update_column(:specific_presentation, @data["specific_presentation"])
      end

      metadata = @data["metadata"] || {}
      @subject.update_column(:code, metadata["code"]) if metadata["code"].present?

      if metadata["variante"].present?
        exam_session.update!(variante: metadata["variante"])
      end

      if metadata["region"].present?
        exam_session.update!(region: metadata["region"])
      end

      if metadata["exam"].present?
        exam_session.update!(exam: metadata["exam"])
      end

      @subject.update_column(:status, Subject.statuses[:pending_validation])

      # Common parts: only create if exam_session has none yet
      unless exam_session.common_parts.any?
        common_doc_refs = Array(@data.dig("document_references", "common_dts")) +
                          Array(@data.dig("document_references", "common_drs"))

        Array(@data["common_parts"]).each_with_index do |part_data, idx|
          part = exam_session.common_parts.create!(
            number:               part_data["number"].to_s,
            title:                part_data["title"].to_s,
            objective_text:       part_data["objective"].to_s,
            section_type:         :common,
            position:             idx,
            document_references:  common_doc_refs
          )

          create_questions_and_answers(part, part_data["questions"])
        end
      end

      # Specific parts: cleanup before recreate (idempotence / retry-safe).
      # Cascade removes associated questions and answers via dependent: :destroy.
      # Common parts (shared via exam_session) are NOT touched.
      @subject.parts.specific.destroy_all

      specific_doc_refs = Array(@data.dig("document_references", "specific_dts")) +
                          Array(@data.dig("document_references", "specific_drs"))

      Array(@data["specific_parts"]).each_with_index do |part_data, idx|
        part = @subject.parts.create!(
          number:               part_data["number"].to_s,
          title:                part_data["title"].to_s,
          objective_text:       part_data["objective"].to_s,
          section_type:         :specific,
          specialty:            @subject.specialty,
          position:             idx,
          document_references:  specific_doc_refs
        )

        create_questions_and_answers(part, part_data["questions"])
      end
    end

    @subject
  end

  private

  def create_questions_and_answers(part, questions_data)
    Array(questions_data).each_with_index do |q_data, q_index|
      question = part.questions.create!(
        number:        q_data["number"].to_s,
        label:         q_data["label"].to_s,
        context_text:  q_data["context"].to_s,
        points:        q_data["points"].to_f,
        answer_type:   normalize_answer_type(q_data["answer_type"]),
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

  def normalize_answer_type(raw)
    ANSWER_TYPE_LEGACY_MAP.fetch(raw.to_s, raw.to_s).presence || "identification"
  end
end
