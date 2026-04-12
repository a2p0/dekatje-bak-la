class Teacher::QuestionsController < Teacher::BaseController
  include ActionView::RecordIdentifier

  before_action :set_question

  def update
    if @question.update(question_params)
      @question.answer&.update(answer_params) if answer_params.values.any?(&:present?)
      render turbo_stream: turbo_stream.replace(
        dom_id(@question),
        partial: "teacher/questions/question",
        locals: { question: @question, subject: @subject, part: @part }
      )
    else
      render turbo_stream: turbo_stream.replace(
        "#{dom_id(@question)}_form",
        partial: "teacher/questions/question_form",
        locals: { question: @question, subject: @subject, part: @part }
      )
    end
  end

  def destroy
    @question.update!(discarded_at: Time.current)
    render turbo_stream: turbo_stream.remove(dom_id(@question))
  end

  private

  def set_question
    @question = Question.kept
                        .joins(:part)
                        .joins("LEFT JOIN subjects ON subjects.id = parts.subject_id")
                        .joins("LEFT JOIN exam_sessions ON exam_sessions.id = parts.exam_session_id")
                        .where("subjects.owner_id = ? OR exam_sessions.owner_id = ?", current_user.id, current_user.id)
                        .find_by(id: params[:id])
    if @question
      @part = @question.part
      @subject = @part.subject || current_user.subjects.joins(:exam_session).find_by(exam_sessions: { id: @part.exam_session_id })
    else
      redirect_to teacher_subjects_path, alert: "Question introuvable."
    end
  end

  def question_params
    params.require(:question).permit(:label, :context_text, :points, :answer_type)
  end

  def answer_params
    params.fetch(:answer, {}).permit(:correction_text, :explanation_text)
  end
end
