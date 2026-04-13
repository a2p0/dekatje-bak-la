# app/controllers/student/questions_controller.rb
class Student::QuestionsController < Student::BaseController
  before_action :set_subject
  before_action :set_session_record
  before_action :set_question

  def show
    @part = @question.part
    @parts = filtered_parts
    @questions_in_part = @part.questions.kept.where(id: filtered_question_ids).order(:position)
    @session_record.mark_seen!(@question.id)

    # Mark specific presentation as seen (from specific presentation page link)
    if params[:mark_specific_seen]
      @session_record.mark_specific_presentation_seen!
    end

    # Load existing conversation for this question (if any)
    @conversation = current_student.conversations.find_by(question: @question)

    # Trigger insight extraction for the previous conversation (if any)
    extract_previous_insights
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
    @session_record = current_student.student_sessions.find_or_create_by!(subject: @subject) do |ss|
      ss.mode = :autonomous
      ss.started_at = Time.current
      ss.last_activity_at = Time.current
    end
  end

  def set_question
    allowed_question_ids = filtered_question_ids
    @question = Question.kept.where(id: allowed_question_ids).find_by(id: params[:id])
    unless @question
      redirect_to student_root_path(access_code: params[:access_code]),
                  alert: "Question introuvable."
    end
  end

  def filtered_parts
    if @session_record.requires_scope_selection? && @session_record.scope_selected?
      @session_record.filtered_parts
    else
      @subject.parts.order(:position)
    end
  end

  def filtered_question_ids
    @filtered_question_ids ||= Question.for_parts(filtered_parts).pluck(:id)
  end

  def extract_previous_insights
    last_id = session[:last_conversation_id]
    return unless last_id

    session.delete(:last_conversation_id)
    conversation = current_student.conversations.find_by(id: last_id)
    return unless conversation && conversation.question_id != @question.id

    ExtractStudentInsightsJob.perform_later(conversation.id)
  end
end
