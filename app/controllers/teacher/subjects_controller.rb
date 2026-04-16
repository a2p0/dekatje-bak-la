class Teacher::SubjectsController < Teacher::BaseController
  before_action :set_subject, only: [ :show, :destroy ]

  def index
    @subjects = current_teacher.subjects.kept.includes(:exam_session).order(created_at: :desc)
  end

  def new
    @subject = Subject.new
    @exam_sessions = current_teacher.exam_sessions.order(:title)
  end

  def create
    @subject = current_teacher.subjects.build(subject_params)

    assign_or_create_exam_session

    if @subject.save
      @subject.create_extraction_job!(status: :pending, provider_used: :server)
      ExtractQuestionsJob.perform_later(@subject.id)
      redirect_to teacher_subject_path(@subject),
                  notice: "Sujet créé. L'extraction démarrera automatiquement."
    else
      @exam_sessions = current_teacher.exam_sessions.order(:title)
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
    params.require(:subject).permit(
      :specialty, :subject_pdf, :correction_pdf, :exam_session_id
    )
  end

  def session_params
    params.require(:subject).permit(:title, :year, :exam, :region)
  end

  def assign_or_create_exam_session
    exam_session_id = params[:subject][:exam_session_id]

    if exam_session_id.present?
      @subject.exam_session = current_teacher.exam_sessions.find(exam_session_id)
    else
      @subject.exam_session = current_teacher.exam_sessions.build(
        session_params.merge(owner: current_teacher)
      )
    end
  end
end
