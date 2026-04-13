class Student::Subjects::CompletionsController < Student::BaseController
  def create
    @subject = @classroom.subjects.published.find(params[:subject_id])

    @session_record = current_student.student_sessions.find_by!(subject: @subject)
    @session_record.mark_subject_completed!

    redirect_to student_subject_path(access_code: params[:access_code], id: @subject.id, completed: true)
  end
end
