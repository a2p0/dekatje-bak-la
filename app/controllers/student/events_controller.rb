class Student::EventsController < Student::BaseController
  ALLOWED_TYPES = %w[viewed_data_hints viewed_correction navigated_here].freeze

  def create
    type = params[:type].to_s
    return head :unprocessable_entity unless ALLOWED_TYPES.include?(type)

    subject = Subject.kept.find(params[:subject_id])
    question = Question.kept.find(params[:question_id])

    conversation = ensure_conversation(subject)

    Tutor::RecordEvent.call(
      conversation: conversation,
      question_id:  question.id,
      type:         type,
      source:       "page_click"
    )

    head :no_content
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end

  private

  def ensure_conversation(subject)
    current_student.conversations.find_or_create_by!(subject: subject) do |c|
      c.tutor_state = TutorState.default
    end
  end
end
