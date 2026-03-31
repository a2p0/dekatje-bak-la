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

    session_record = current_student.student_sessions.find_or_create_by!(subject: @subject) do |ss|
      ss.mode = :autonomous
      ss.started_at = Time.current
      ss.last_activity_at = Time.current
    end

    part = if params[:part_id]
             @subject.parts.find_by(id: params[:part_id])
    end
    part ||= @subject.parts.order(:position).first

    unless part
      return redirect_to student_root_path(access_code: params[:access_code]),
                         alert: "Ce sujet n'a pas encore de questions."
    end

    question = session_record.first_undone_question(part)
    redirect_to student_question_path(
      access_code: params[:access_code],
      subject_id: @subject.id,
      id: question.id
    )
  end
end
