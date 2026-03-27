class Teacher::SubjectsController < Teacher::BaseController
  before_action :set_subject, only: [ :show, :publish, :archive ]

  def index
    @subjects = current_teacher.subjects.kept.order(created_at: :desc)
  end

  def new
    @subject = Subject.new
  end

  def create
    @subject = current_teacher.subjects.build(subject_params)

    if @subject.save
      @subject.create_extraction_job!(status: :pending, provider_used: :server)
      redirect_to teacher_subject_path(@subject),
                  notice: "Sujet créé. L'extraction démarrera automatiquement."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @extraction_job = @subject.extraction_job
  end

  def publish
    unless @subject.draft? || @subject.pending_validation?
      return redirect_to teacher_subject_path(@subject),
                         alert: "Ce sujet ne peut pas être publié."
    end

    @subject.update!(status: :published)
    redirect_to teacher_subject_path(@subject), notice: "Sujet publié."
  end

  def archive
    unless @subject.published?
      return redirect_to teacher_subject_path(@subject),
                         alert: "Seul un sujet publié peut être archivé."
    end

    @subject.update!(status: :archived)
    redirect_to teacher_subject_path(@subject), notice: "Sujet archivé."
  end

  private

  def set_subject
    @subject = current_teacher.subjects.find_by(id: params[:id])
    redirect_to teacher_subjects_path, alert: "Sujet introuvable." unless @subject
  end

  def subject_params
    params.require(:subject).permit(
      :title, :year, :exam_type, :specialty, :region,
      :enonce_file, :dt_file, :dr_vierge_file, :dr_corrige_file, :questions_corrigees_file
    )
  end
end
