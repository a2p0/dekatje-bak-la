class Student::Subjects::PartCompletionsController < Student::BaseController
  def create
    @subject = @classroom.subjects.published.find_by(id: params[:subject_id])
    unless @subject
      return redirect_to student_root_path(access_code: params[:access_code]),
                         alert: "Sujet introuvable."
    end

    @session_record = current_student.student_sessions.find_by!(subject: @subject)
    completed_part = Part.find_by(id: params[:part_id])
    @session_record.mark_part_completed!(params[:part_id].to_i)

    # If every filtered part is completed, defer to subject#show which handles
    # unanswered review / completion via its existing flow.
    if @session_record.all_parts_completed?
      return redirect_to student_subject_path(access_code: params[:access_code], id: @subject.id)
    end

    # Otherwise route to the target section's next unanswered question (or its
    # presentation if the target's first question has never been answered).
    target_section = completed_part&.section_type == "specific" ? "common" : "specific"
    all_parts = @session_record.filtered_parts.to_a
    target_parts = all_parts.select { |p| p.section_type == target_section }

    if target_parts.empty?
      return redirect_to student_subject_path(access_code: params[:access_code], id: @subject.id)
    end

    target_first_question = target_parts.first.questions.kept.order(:position).first

    # If the target section's first question hasn't been answered yet and that
    # section has a presentation page, route through it (subject#show will render
    # the specific or common presentation as appropriate). Otherwise jump straight
    # to the first unanswered question of the target section.
    show_presentation = target_first_question &&
                        !@session_record.answered?(target_first_question.id) &&
                        target_section == "specific" &&
                        @subject.specific_presentation.present?

    if show_presentation
      return redirect_to student_subject_path(
        access_code: params[:access_code],
        id: @subject.id,
        start: true
      )
    end

    first_unanswered = target_parts
      .flat_map { |p| p.questions.kept.order(:position).to_a }
      .detect { |q| !@session_record.answered?(q.id) }

    if first_unanswered
      redirect_to student_question_path(
        access_code: params[:access_code],
        subject_id: @subject.id,
        id: first_unanswered.id
      )
    else
      redirect_to student_subject_path(access_code: params[:access_code], id: @subject.id)
    end
  end
end
