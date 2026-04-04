class Student::SubjectsController < Student::BaseController
  def index
    @subjects = @classroom.subjects.published.order(:title)
  end

  def show
    @subject = @classroom.subjects.published.find_by(id: params[:id])
    unless @subject
      return redirect_to student_root_path(access_code: params[:access_code]),
                         alert: "Sujet introuvable."
    end

    @session_record = current_student.student_sessions.find_or_create_by!(subject: @subject) do |ss|
      ss.mode = :autonomous
      ss.started_at = Time.current
      ss.last_activity_at = Time.current
    end

    # Legacy subjects (no exam_session) have all parts directly on subject
    # New format subjects may combine exam_session common_parts + subject specific_parts
    all_parts = if @subject.exam_session.present?
                  @subject.exam_session.common_parts.order(:position) +
                    @subject.parts.where(section_type: :specific).order(:position)
    else
                  @subject.parts.order(:position)
    end

    part = if params[:part_id]
             all_parts.find { |p| p.id == params[:part_id].to_i }
    end
    part ||= all_parts.first

    unless part
      return redirect_to student_root_path(access_code: params[:access_code]),
                         alert: "Ce sujet n'a pas encore de questions."
    end

    # Show mise en situation page on first visit (no answers yet), unless explicitly starting
    if params[:start].blank? && @session_record.answered_count.zero?
      @parts = all_parts
      @first_question = part.questions.kept.order(:position).first
      return render :show
    end

    question = @session_record.first_undone_question(part)
    redirect_to student_question_path(
      access_code: params[:access_code],
      subject_id: @subject.id,
      id: question.id
    )
  end
end
