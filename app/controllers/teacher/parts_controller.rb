class Teacher::PartsController < Teacher::BaseController
  before_action :set_subject
  before_action :set_part

  def show
    @questions = @part.questions.kept.order(:position)
    @parts = @subject.parts.order(:position)
  end

  private

  def set_subject
    @subject = current_teacher.subjects.find_by(id: params[:subject_id])
    redirect_to teacher_subjects_path, alert: "Sujet introuvable." unless @subject
  end

  def set_part
    @part = @subject.parts.find_by(id: params[:id])
    redirect_to teacher_subject_path(@subject), alert: "Partie introuvable." unless @part
  end
end
