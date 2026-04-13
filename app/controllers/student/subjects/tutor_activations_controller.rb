class Student::Subjects::TutorActivationsController < Student::BaseController
  def create
    @subject = @classroom.subjects.published.find(params[:subject_id])

    session_record = current_student.student_sessions.find_or_create_by!(subject: @subject) do |s|
      s.mode = :tutored
      s.progression = {}
      s.started_at = Time.current
      s.last_activity_at = Time.current
      s.tutor_state = {}
    end

    unless session_record.tutored?
      session_record.tutor_state = {} if session_record.tutor_state.blank?
      session_record.update!(mode: :tutored, tutor_state: session_record.tutor_state)
    end

    redirect_to student_subject_path(access_code: params[:access_code], id: @subject.id),
                notice: "Mode tuteur activé. Le tuteur IA vous accompagnera à chaque question."
  end
end
