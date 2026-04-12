class Teacher::ClassroomsController < Teacher::BaseController
  before_action :set_classroom, only: [ :show ]

  def index
    @classrooms = current_teacher.classrooms.includes(:students).order(created_at: :desc)
    @recent_subjects = current_teacher.subjects.kept.order(created_at: :desc).limit(5)
  end

  def new
    @classroom = Classroom.new
  end

  def create
    access_code = GenerateAccessCode.call(
      specialty: classroom_params[:specialty],
      school_year: classroom_params[:school_year]
    )
    @classroom = current_teacher.classrooms.build(classroom_params.merge(access_code: access_code))

    if @classroom.save
      redirect_to teacher_classroom_path(@classroom),
                  notice: "Classe créée avec succès."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @students = @classroom.students.order(:last_name, :first_name)
    @generated_credentials = session.delete(:generated_credentials)
  end

  private

  def set_classroom
    @classroom = current_teacher.classrooms.find_by(id: params[:id])
    redirect_to teacher_root_path, alert: "Classe introuvable." unless @classroom
  end

  def classroom_params
    params.require(:classroom).permit(:name, :school_year, :specialty)
  end
end
