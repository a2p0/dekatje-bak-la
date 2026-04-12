class Teacher::Subjects::PublicationsController < Teacher::BaseController
  before_action :set_subject
  rescue_from Subject::InvalidTransition, with: :invalid_transition

  def create
    @subject.publish!
    respond_to do |format|
      format.html { redirect_to assign_teacher_subject_path(@subject), notice: "Sujet publié. Assignez-le maintenant aux classes." }
      format.turbo_stream
    end
  end

  def destroy
    @subject.unpublish!
    respond_to do |format|
      format.html { redirect_to teacher_subject_path(@subject), notice: "Sujet dépublié." }
      format.turbo_stream
    end
  end

  private

  def set_subject
    @subject = current_user.subjects.find(params[:subject_id])
  end

  def invalid_transition(exception)
    redirect_to teacher_subject_path(@subject), alert: exception.message
  end
end
