class Teacher::QuestionsController < Teacher::BaseController
  include ActionView::RecordIdentifier

  before_action :set_subject
  before_action :set_part
  before_action :set_question

  def update
    if @question.update(question_params)
      @question.answer&.update(answer_params) if answer_params.values.any?(&:present?)
      render turbo_stream: turbo_stream.replace(
        dom_id(@question),
        partial: "teacher/questions/question",
        locals: { question: @question, subject: @subject, part: @part }
      )
    else
      render turbo_stream: turbo_stream.replace(
        "#{dom_id(@question)}_form",
        partial: "teacher/questions/question_form",
        locals: { question: @question, subject: @subject, part: @part }
      )
    end
  end

  def destroy
    @question.update!(discarded_at: Time.current)
    render turbo_stream: turbo_stream.remove(dom_id(@question))
  end

  def validate
    @question.update!(status: :validated)
    render turbo_stream: turbo_stream.replace(
      dom_id(@question),
      partial: "teacher/questions/question",
      locals: { question: @question, subject: @subject, part: @part }
    )
  end

  def invalidate
    @question.update!(status: :draft)
    render turbo_stream: turbo_stream.replace(
      dom_id(@question),
      partial: "teacher/questions/question",
      locals: { question: @question, subject: @subject, part: @part }
    )
  end

  private

  def set_subject
    @subject = current_teacher.subjects.find_by(id: params[:subject_id])
    redirect_to teacher_subjects_path, alert: "Sujet introuvable." unless @subject
  end

  def set_part
    @part = all_parts_for_subject.find { |p| p.id == params[:part_id].to_i }
    redirect_to teacher_subject_path(@subject), alert: "Partie introuvable." unless @part
  end

  def all_parts_for_subject
    if @subject.exam_session.present?
      @subject.exam_session.common_parts.to_a + @subject.parts.where(section_type: :specific).to_a
    else
      @subject.parts.to_a
    end
  end

  def set_question
    @question = @part.questions.kept.find_by(id: params[:id])
    redirect_to teacher_subject_part_path(@subject, @part), alert: "Question introuvable." unless @question
  end

  def question_params
    params.require(:question).permit(:label, :context_text, :points, :answer_type)
  end

  def answer_params
    params.fetch(:answer, {}).permit(:correction_text, :explanation_text)
  end
end
