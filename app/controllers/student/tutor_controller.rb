class Student::TutorController < Student::BaseController
  before_action :set_subject
  before_action :set_question, except: [:activate]
  before_action :set_session_record

  def activate
    # TODO: implement in US2
    head :ok
  end

  def verify_spotting
    # TODO: implement in US1
    head :ok
  end

  def skip_spotting
    # TODO: implement in US1
    head :ok
  end

  private

  def set_subject
    @subject = @classroom.subjects.find(params[:subject_id])
  end

  def set_question
    @question = @subject.parts.joins(:questions).merge(Question.kept).find(params[:question_id])
  end

  def set_session_record
    @session_record = current_student.student_sessions.find_by!(subject: @subject)
  end
end
