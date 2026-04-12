class Teacher::Subjects::AssignmentsController < Teacher::BaseController
  before_action :set_subject

  def edit
    @classrooms = current_user.classrooms.order(:name)
    @assigned_ids = @subject.classroom_ids
  end

  def update
    selected_ids = Array(params[:classroom_ids]).map(&:to_i)
    @subject.classroom_ids = selected_ids
    redirect_to teacher_subject_path(@subject), notice: "Assignation mise à jour."
  end

  private

  def set_subject
    @subject = current_user.subjects.find(params[:subject_id])
  end
end
