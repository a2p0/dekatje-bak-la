class Teacher::Questions::ValidationsController < Teacher::BaseController
  before_action :set_question
  rescue_from Question::InvalidTransition, with: :invalid_transition

  def create
    @question.validate!
    render_question_update
  end

  def destroy
    @question.invalidate!
    render_question_update
  end

  private

  def set_question
    @question = Question.kept
                        .joins(:part)
                        .joins("LEFT JOIN subjects ON subjects.id = parts.subject_id")
                        .joins("LEFT JOIN exam_sessions ON exam_sessions.id = parts.exam_session_id")
                        .where("subjects.owner_id = ? OR exam_sessions.owner_id = ?", current_user.id, current_user.id)
                        .find(params[:question_id])
  end

  def render_question_update
    part = @question.part
    subject = part.subject || current_user.subjects.joins(:exam_session).find_by(exam_sessions: { id: part.exam_session_id })
    render turbo_stream: turbo_stream.replace(
      ActionView::RecordIdentifier.dom_id(@question),
      partial: "teacher/questions/question",
      locals: { question: @question, subject: subject, part: part }
    )
  end

  def invalid_transition(exception)
    render turbo_stream: turbo_stream.replace(
      "flash",
      partial: "shared/flash",
      locals: { alert: exception.message }
    )
  end
end
