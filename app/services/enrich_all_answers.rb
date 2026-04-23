class EnrichAllAnswers
  def self.call(subject:, api_key:, provider:)
    new(subject: subject, api_key: api_key, provider: provider).call
  end

  def initialize(subject:, api_key:, provider:)
    @subject  = subject
    @api_key  = api_key
    @provider = provider
  end

  def call
    enriched = 0
    skipped  = 0
    errors   = 0

    answers.each do |answer|
      if answer.structured_correction.present?
        skipped += 1
        next
      end

      result = EnrichStructuredCorrection.call(answer: answer, api_key: @api_key, provider: @provider)

      if result.ok?
        answer.update!(structured_correction: result.structured_correction)
        enriched += 1
      else
        Rails.logger.warn("[EnrichAllAnswers] #{answer.question.number}: #{result.error}")
        errors += 1
      end
    rescue StandardError => e
      Rails.logger.warn("[EnrichAllAnswers] unexpected error for answer #{answer.id}: #{e.message}")
      errors += 1
    end

    { enriched: enriched, skipped: skipped, errors: errors }
  end

  private

  def answers
    @subject.parts
            .includes(questions: :answer)
            .flat_map(&:questions)
            .filter_map(&:answer)
  end
end
