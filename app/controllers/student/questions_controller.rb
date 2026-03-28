class Student::QuestionsController < Student::BaseController
  before_action :set_subject
  before_action :set_question
  before_action :set_session_record

  def show
    @part = @question.part
    @parts = @subject.parts.order(:position)
    @questions_in_part = @part.questions.kept.order(:position)
    @session_record.mark_seen!(@question.id)
  end

  def reveal
    @session_record.mark_answered!(@question.id)
    render turbo_stream: turbo_stream.replace(
      "question_#{@question.id}_correction",
      partial: "student/questions/correction",
      locals: { question: @question, subject: @subject, session_record: @session_record }
    )
  end

  private

  def set_subject
    @subject = @classroom.subjects.published.find_by(id: params[:subject_id])
    unless @subject
      redirect_to student_root_path(access_code: params[:access_code]),
                  alert: "Sujet introuvable."
    end
  end

  def set_question
    @question = Question.kept.joins(:part)
                        .where(parts: { subject_id: @subject.id })
                        .find_by(id: params[:id])
    unless @question
      redirect_to student_root_path(access_code: params[:access_code]),
                  alert: "Question introuvable."
    end
  end

  def set_session_record
    @session_record = current_student.student_sessions.find_or_create_by!(subject: @subject) do |ss|
      ss.mode = :autonomous
      ss.started_at = Time.current
      ss.last_activity_at = Time.current
    end
  end
end
