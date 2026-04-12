class Teacher::Subjects::ExtractionsController < Teacher::BaseController
  before_action :set_subject

  def create
    job = @subject.extraction_job

    unless job&.failed?
      return redirect_to teacher_subject_path(@subject),
                         alert: "L'extraction ne peut être relancée que si elle a échoué."
    end

    job.update!(status: :processing, error_message: nil)
    ExtractQuestionsJob.perform_later(@subject.id)
    redirect_to teacher_subject_path(@subject), notice: "Extraction relancée."
  end

  private

  def set_subject
    @subject = current_user.subjects.find(params[:subject_id])
  end
end
