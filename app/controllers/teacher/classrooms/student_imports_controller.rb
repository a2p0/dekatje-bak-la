class Teacher::Classrooms::StudentImportsController < Teacher::BaseController
  before_action :set_classroom

  def new
  end

  def create
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

  private

  def set_classroom
    @classroom = current_user.classrooms.find(params[:classroom_id])
  end
end
