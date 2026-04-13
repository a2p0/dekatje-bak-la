class Student::Subjects::ScopeSelectionsController < Student::BaseController
  before_action :set_subject

  def update
    @session_record = current_student.student_sessions.find_by!(subject: @subject)
    @session_record.update!(part_filter: params[:part_filter], scope_selected: true)
    redirect_to student_subject_path(access_code: params[:access_code], id: @subject.id)
  end

  private

  def set_subject
    @subject = @classroom.subjects.published.find(params[:subject_id])
  end
end
