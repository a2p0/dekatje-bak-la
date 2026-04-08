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

    # 1. Scope selection needed
    if @session_record.requires_scope_selection? && !@session_record.scope_selected?
      @parts = all_parts_for_subject
      return render :show
    end

    all_parts = filtered_parts_for_session

    unless all_parts.any?
      return redirect_to student_root_path(access_code: params[:access_code]),
                         alert: "Ce sujet n'a pas encore de questions."
    end

    # 2. Subject completed → relecture mode (parts list with badges)
    if @session_record.subject_completed?
      @parts = all_parts
      @relecture_mode = true
      return render :show
    end

    # 3. All parts completed + unanswered questions → unanswered page
    if @session_record.all_parts_completed?
      unanswered = @session_record.unanswered_questions
      if unanswered.any?
        @unanswered_questions = unanswered
        @parts = all_parts
        return render :show
      else
        # 4. All parts completed + all answered → completion page
        @show_completion = true
        return render :show
      end
    end

    # 5. First visit (no progress) → mise en situation + parts list
    if params[:start].blank? && @session_record.answered_count.zero? && !@session_record.progression["parts_completed"]&.any?
      @parts = all_parts
      @first_question = first_incomplete_part_question(all_parts)
      return render :show
    end

    # 6. Specific part next + specific presentation not seen
    if should_show_specific_presentation?(all_parts)
      @show_specific_presentation = true
      @parts = all_parts
      @first_specific_question = first_specific_question(all_parts)
      return render :show
    end

    # 7. Default → redirect to first undone question
    part = target_part(all_parts)
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

    redirect_to student_subject_path(access_code: params[:access_code], id: @subject.id)
  end

  def complete_part
    @subject = @classroom.subjects.published.find_by(id: params[:id])
    unless @subject
      return redirect_to student_root_path(access_code: params[:access_code]),
                         alert: "Sujet introuvable."
    end

    @session_record = current_student.student_sessions.find_by!(subject: @subject)
    @session_record.mark_part_completed!(params[:part_id].to_i)

    redirect_to student_subject_path(access_code: params[:access_code], id: @subject.id)
  end

  def complete
    @subject = @classroom.subjects.published.find_by(id: params[:id])
    unless @subject
      return redirect_to student_root_path(access_code: params[:access_code]),
                         alert: "Sujet introuvable."
    end

    @session_record = current_student.student_sessions.find_by!(subject: @subject)
    @session_record.mark_subject_completed!

    redirect_to student_subject_path(access_code: params[:access_code], id: @subject.id)
  end

  private

  def filtered_parts_for_session
    if @session_record.requires_scope_selection?
      @session_record.filtered_parts.to_a
    else
      all_parts_for_subject
    end
  end

  def all_parts_for_subject
    if @subject.exam_session.present?
      @subject.exam_session.common_parts.order(:position).to_a +
        @subject.parts.where(section_type: :specific).order(:position).to_a
    else
      @subject.parts.order(:position).to_a
    end
  end

  def should_show_specific_presentation?(all_parts)
    return false if @session_record.specific_presentation_seen?
    return false if @subject.specific_presentation.blank?

    common_parts = all_parts.select { |p| p.section_type == "common" }
    specific_parts = all_parts.select { |p| p.section_type == "specific" }

    return false if specific_parts.empty?

    # For specific_only scope, show on first visit
    if @session_record.specific_only?
      return true
    end

    # For full scope, show when all common parts are completed
    common_parts.empty? || common_parts.all? { |p| @session_record.part_completed?(p.id) }
  end

  def first_specific_question(all_parts)
    specific_part = all_parts.find { |p| p.section_type == "specific" }
    return nil unless specific_part
    @session_record.first_undone_question(specific_part)
  end

  def first_incomplete_part_question(all_parts)
    part = all_parts.find { |p| !@session_record.part_completed?(p.id) }
    part ||= all_parts.first
    part&.questions&.kept&.order(:position)&.first
  end

  def target_part(all_parts)
    if params[:part_id]
      part = all_parts.find { |p| p.id == params[:part_id].to_i }
      return part if part
    end

    # Find first incomplete part
    all_parts.find { |p| !@session_record.part_completed?(p.id) } || all_parts.first
  end
end
