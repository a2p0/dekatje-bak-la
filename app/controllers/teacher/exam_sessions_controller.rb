class Teacher::ExamSessionsController < Teacher::BaseController
  def destroy
    @exam_session = current_teacher.exam_sessions.find(params[:id])

    unless @exam_session.destroy
      return redirect_to teacher_subjects_path,
                         alert: "Impossible de supprimer cette session : #{@exam_session.errors.full_messages.join(', ')}."
    end

    redirect_to teacher_subjects_path,
                notice: "Session « #{@exam_session.title} » supprimée avec ses parties communes."
  end
end
