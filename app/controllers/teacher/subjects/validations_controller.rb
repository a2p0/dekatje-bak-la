class Teacher::Subjects::ValidationsController < Teacher::BaseController
  before_action :set_subject

  def show
    extraction_job = @subject.extraction_job
    raw_json = extraction_job&.raw_json

    @metadata         = MapExtractedMetadata.call(raw_json)
    @existing_session = MatchExamSession.call(
      owner: current_teacher,
      title: @metadata[:title],
      year:  @metadata[:year]
    )
    @extraction_failed = extraction_job&.failed? || false
  end

  def update
    exam_session = resolve_exam_session
    @subject.assign_attributes(
      specialty:    validation_params[:specialty],
      status:       :draft,
      exam_session: exam_session
    )

    if @subject.save
      redirect_to teacher_subject_path(@subject),
                  notice: "Sujet créé avec succès."
    else
      @metadata = validation_params.to_h.symbolize_keys
      @existing_session = MatchExamSession.call(
        owner: current_teacher,
        title: @metadata[:title],
        year:  @metadata[:year]
      )
      @extraction_failed = false
      render :show, status: :unprocessable_entity
    end
  end

  private

  def set_subject
    @subject = current_teacher.subjects.find_by(id: params[:subject_id])
    redirect_to teacher_subjects_path, alert: "Sujet introuvable." unless @subject
  end

  def validation_params
    params.require(:subject).permit(
      :title, :year, :exam, :region, :variante, :specialty,
      :exam_session_choice, :exam_session_id
    )
  end

  def resolve_exam_session
    if validation_params[:exam_session_choice] == "attach" && validation_params[:exam_session_id].present?
      current_teacher.exam_sessions.find(validation_params[:exam_session_id])
    else
      current_teacher.exam_sessions.build(
        title:    validation_params[:title],
        year:     validation_params[:year],
        exam:     validation_params[:exam],
        region:   validation_params[:region],
        variante: validation_params[:variante].presence || "normale",
        owner:    current_teacher
      )
    end
  end
end
