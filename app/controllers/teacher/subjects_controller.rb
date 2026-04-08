class Teacher::SubjectsController < Teacher::BaseController
  before_action :set_subject, only: [ :show, :publish, :archive, :unpublish, :retry_extraction, :assign ]

  def index
    @subjects = current_teacher.subjects.kept.order(created_at: :desc)
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

  def publish
    unless @subject.publishable?
      return redirect_to teacher_subject_path(@subject),
                         alert: "Publiez au moins une question validée avant de publier."
    end

    @subject.update!(status: :published)
    redirect_to assign_teacher_subject_path(@subject),
                notice: "Sujet publié. Assignez-le maintenant aux classes."
  end

  def unpublish
    unless @subject.published?
      return redirect_to teacher_subject_path(@subject),
                         alert: "Seul un sujet publié peut être dépublié."
    end

    @subject.update!(status: :draft)
    redirect_to teacher_subject_path(@subject), notice: "Sujet dépublié."
  end

  def assign
    @classrooms = current_teacher.classrooms.order(:name)
    @assigned_ids = @subject.classroom_ids

    if request.patch?
      selected_ids = Array(params[:classroom_ids]).map(&:to_i)
      @subject.classroom_ids = selected_ids
      redirect_to teacher_subject_path(@subject), notice: "Assignation mise à jour."
    end
  end

  def retry_extraction
    job = @subject.extraction_job
    unless job&.failed?
      return redirect_to teacher_subject_path(@subject),
                         alert: "L'extraction ne peut être relancée que si elle a échoué."
    end

    job.update!(status: :processing, error_message: nil)
    ExtractQuestionsJob.perform_later(@subject.id)
    redirect_to teacher_subject_path(@subject),
                notice: "Extraction relancée."
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
