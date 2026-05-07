class Student::EventsController < Student::BaseController
  # Subset of Tutor::RecordEvent::ALLOWED_TYPES — only events triggered by page UI clicks.
  ALLOWED_TYPES = %w[viewed_data_hints viewed_correction navigated_here].freeze

  def create
    type = params[:type].to_s
    return head :unprocessable_entity unless ALLOWED_TYPES.include?(type)

    subject = Subject.kept.find(params[:subject_id])
    question = Question.kept.find(params[:question_id])

    conversation = ensure_conversation(subject)

    result = Tutor::RecordEvent.call(
      conversation: conversation,
      question_id:  question.id,
      type:         type,
      source:       "page_click"
    )

    return head :internal_server_error unless result.ok?

    head :no_content
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end

  private

  def ensure_conversation(subject)
    Student::EnsureConversation.call(student: current_student, subject: subject)
  end
end
