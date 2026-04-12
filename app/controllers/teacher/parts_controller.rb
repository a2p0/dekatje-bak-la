class Teacher::PartsController < Teacher::BaseController
  before_action :set_subject
  before_action :set_part

  def show
    @questions = @part.questions.kept.order(:position)
    @parts = all_parts_for_subject
  end

  private

  def set_subject
    @subject = current_teacher.subjects.find_by(id: params[:subject_id])
    redirect_to teacher_subjects_path, alert: "Sujet introuvable." unless @subject
  end

  def set_part
    @part = all_parts_for_subject.find { |p| p.id == params[:id].to_i }
    redirect_to teacher_subject_path(@subject), alert: "Partie introuvable." unless @part
  end

  def all_parts_for_subject
    @all_parts ||= if @subject.exam_session.present?
      @subject.exam_session.common_parts.order(:position).to_a +
        @subject.parts.specific.order(:position).to_a
    else
      @subject.parts.order(:position).to_a
    end
  end
end
