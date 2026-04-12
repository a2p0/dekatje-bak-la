class Teacher::StudentsController < Teacher::BaseController
  before_action :set_classroom

  def new
    @student = Student.new
  end

  def create
    credentials = GenerateStudentCredentials.call(
      first_name: student_params[:first_name],
      last_name: student_params[:last_name],
      classroom: @classroom
    )

    student = @classroom.students.build(
      first_name: student_params[:first_name],
      last_name: student_params[:last_name],
      username: credentials.username,
      password: credentials.password
    )

    if student.save
      session[:generated_credentials] = [
        { "name" => "#{student.first_name} #{student.last_name}",
          "username" => credentials.username,
          "password" => credentials.password }
      ]
      redirect_to teacher_classroom_path(@classroom),
                  notice: "Élève ajouté. Notez les identifiants ci-dessous."
    else
      @student = student
      render :new, status: :unprocessable_entity
    end
  end

  private

  def set_classroom
    @classroom = current_teacher.classrooms.find_by(id: params[:classroom_id])
    redirect_to teacher_root_path, alert: "Classe introuvable." unless @classroom
  end

  def student_params
    params.require(:student).permit(:first_name, :last_name)
  end
end
