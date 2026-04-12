class Teacher::StudentsController < Teacher::BaseController
  before_action :set_classroom
  before_action :set_student, only: [ :reset_password ]

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

  def bulk_new
  end

  def bulk_create
    lines = params[:students_list].to_s.split("\n").map(&:strip).reject(&:empty?)
    generated = []
    errors = []

    lines.each do |line|
      parts = line.split(" ", 2)
      if parts.length < 2
        errors << "Ligne ignorée (format invalide) : #{line}"
        next
      end

      first_name, last_name = parts[0], parts[1]
      credentials = GenerateStudentCredentials.call(
        first_name: first_name,
        last_name: last_name,
        classroom: @classroom
      )

      student = @classroom.students.build(
        first_name: first_name,
        last_name: last_name,
        username: credentials.username,
        password: credentials.password
      )

      if student.save
        generated << { "name" => "#{first_name} #{last_name}",
                       "username" => credentials.username,
                       "password" => credentials.password }
      else
        errors << "Erreur pour #{line} : #{student.errors.full_messages.join(", ")}"
      end
    end

    session[:generated_credentials] = generated if generated.any?

    if errors.any?
      flash[:alert] = errors.join(" | ")
    else
      flash[:notice] = "#{generated.count} élèves ajoutés. Notez les identifiants ci-dessous."
    end

    redirect_to teacher_classroom_path(@classroom)
  end

  def reset_password
    password = ResetStudentPassword.call(student: @student)
    session[:generated_credentials] = [
      { "name" => "#{@student.first_name} #{@student.last_name}",
        "username" => @student.username,
        "password" => password }
    ]
    redirect_to teacher_classroom_path(@classroom),
                notice: "Mot de passe réinitialisé. Notez le nouveau mot de passe ci-dessous."
  end

  private

  def set_classroom
    @classroom = current_teacher.classrooms.find_by(id: params[:classroom_id])
    redirect_to teacher_root_path, alert: "Classe introuvable." unless @classroom
  end

  def set_student
    @student = @classroom.students.find_by(id: params[:id])
    redirect_to teacher_classroom_path(@classroom), alert: "Élève introuvable." unless @student
  end

  def student_params
    params.require(:student).permit(:first_name, :last_name)
  end
end
