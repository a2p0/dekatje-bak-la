class Student::SubjectsController < Student::BaseController
  def index
    @subjects = @classroom.subjects.published.includes(:exam_session).order(:created_at)
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

    # New-format subjects require scope selection before starting
    if @session_record.requires_scope_selection? && !@session_record.scope_selected?
      @parts = all_parts_for_subject
      return render :show
    end

    # Use filtered parts based on scope selection
    all_parts = @session_record.requires_scope_selection? ? @session_record.filtered_parts.to_a : all_parts_for_subject

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

  def set_scope
    @subject = @classroom.subjects.published.find_by(id: params[:id])
    unless @subject
      return redirect_to student_root_path(access_code: params[:access_code]),
                         alert: "Sujet introuvable."
    end

    @session_record = current_student.student_sessions.find_by!(subject: @subject)
    @session_record.update!(part_filter: params[:part_filter], scope_selected: true)

    # Redirect to the subject show (which will now show mise en situation or first question)
    redirect_to student_subject_path(access_code: params[:access_code], id: @subject.id)
  end

  private

  def all_parts_for_subject
    if @subject.exam_session.present?
      @subject.exam_session.common_parts.order(:position).to_a +
        @subject.parts.where(section_type: :specific).order(:position).to_a
    else
      @subject.parts.order(:position).to_a
    end
  end
end
