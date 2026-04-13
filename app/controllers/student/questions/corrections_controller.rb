# app/controllers/student/questions/corrections_controller.rb
class Student::Questions::CorrectionsController < Student::BaseController
  before_action :set_subject
  before_action :set_session_record
  before_action :set_question

  def create
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

  def set_session_record
    @session_record = current_student.student_sessions.find_by!(subject: @subject)
  end

  def set_question
    # Allow any question belonging to this subject directly (specific parts)
    # or to its exam_session (shared common parts).
    part_ids = @subject.parts.pluck(:id)
    part_ids += @subject.exam_session.common_parts.pluck(:id) if @subject.exam_session
    @question = Question.kept.where(part_id: part_ids).find_by(id: params[:question_id])
    unless @question
      redirect_to student_root_path(access_code: params[:access_code]),
                  alert: "Question introuvable."
    end
  end
end
