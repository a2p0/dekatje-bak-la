class Teacher::SubjectsController < Teacher::BaseController
  before_action :set_subject, only: [ :show, :destroy ]

  def index
    @pending_subjects = current_teacher.subjects.kept.where(status: :uploading).order(created_at: :desc)
    @subjects         = current_teacher.subjects.visible.includes(:exam_session).order(created_at: :desc)
  end

  def new
    @subject = Subject.new
  end

  def create
    @subject = current_teacher.subjects.build(subject_params)
    @subject.status = :uploading

    if @subject.save
      @subject.create_extraction_job!(status: :pending, provider_used: :server)
      ExtractQuestionsJob.perform_later(@subject.id)
      redirect_to teacher_subject_path(@subject),
                  notice: "Fichiers importés. L'extraction démarrera automatiquement."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @extraction_job = @subject.extraction_job
  end

  def destroy
    title = @subject.title.presence || "sans titre"
    @subject.update!(discarded_at: Time.current)
    redirect_to teacher_subjects_path,
                notice: "Sujet « #{title} » archivé."
  end

  private

  def set_subject
    @subject = current_teacher.subjects.kept.find_by(id: params[:id])
    redirect_to teacher_subjects_path, alert: "Sujet introuvable." unless @subject
  end

  def subject_params
    params.require(:subject).permit(:subject_pdf, :correction_pdf)
  end
end
