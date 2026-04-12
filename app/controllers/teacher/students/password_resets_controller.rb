class Teacher::Students::PasswordResetsController < Teacher::BaseController
  before_action :set_student

  def create
    password = ResetStudentPassword.call(student: @student)
    session[:generated_credentials] = [
      { "name" => "#{@student.first_name} #{@student.last_name}",
        "username" => @student.username,
        "password" => password }
    ]
    redirect_to teacher_classroom_path(@student.classroom),
                notice: "Mot de passe réinitialisé. Notez le nouveau mot de passe ci-dessous."
  end

  private

  def set_student
    @student = Student.joins(:classroom)
                      .where(classrooms: { owner_id: current_user.id })
                      .find(params[:student_id])
  end
end
