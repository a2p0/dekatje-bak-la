# app/jobs/extract_student_insights_job.rb
class ExtractStudentInsightsJob < ApplicationJob
  queue_as :low_priority

  def perform(conversation_id)
    conversation = Conversation.find_by(id: conversation_id)
    return unless conversation

    ExtractStudentInsights.call(conversation: conversation)
  rescue StandardError => e
    Rails.logger.error("[ExtractStudentInsightsJob] #{e.class}: #{e.message}")
  end
end
