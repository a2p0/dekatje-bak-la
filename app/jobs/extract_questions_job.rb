class ExtractQuestionsJob < ApplicationJob
  queue_as :extraction

  def perform(subject_id)
    subject = Subject.find(subject_id)
    job = subject.extraction_job
    return if job.nil? || job.done?

    job.update!(status: :processing)

    resolved = ResolveApiKey.call(user: subject.owner)
    skip_common = subject.exam_session&.common_parts&.any? || false
    raw_response, data = ExtractQuestionsFromPdf.call(
      subject: subject,
      api_key: resolved.api_key,
      provider: resolved.provider,
      skip_common: skip_common
    )
    PersistExtractedData.call(subject: subject, data: data)

    provider_used = subject.owner.api_key.present? ? :teacher : :server
    job.update!(status: :done, raw_json: raw_response, provider_used: provider_used)

    broadcast_extraction_status(subject)
  rescue => e
    job&.update!(status: :failed, error_message: e.message, raw_json: raw_response)
    broadcast_extraction_status(subject) if subject
  end

  private

  def broadcast_extraction_status(subject)
    subject.reload
    stream = "subject_#{subject.id}"

    Turbo::StreamsChannel.broadcast_replace_to(
      stream, target: "extraction-status",
      partial: "teacher/subjects/extraction_status",
      locals: { subject: subject }
    )
    Turbo::StreamsChannel.broadcast_replace_to(
      stream, target: "parts-list",
      partial: "teacher/subjects/parts_list",
      locals: { subject: subject }
    )
    Turbo::StreamsChannel.broadcast_replace_to(
      stream, target: "subject_stats_#{subject.id}",
      partial: "teacher/subjects/stats",
      locals: { subject: subject }
    )
  end
end
