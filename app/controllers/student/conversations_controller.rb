# app/controllers/student/conversations_controller.rb
class Student::ConversationsController < Student::BaseController
  before_action :require_api_key, only: [:create, :message]
  before_action :set_conversation, only: [:message]

  def create
    question = Question.kept.find(params[:question_id])
    conversation = current_student.conversations.find_or_create_by!(question: question)

    render json: { conversation_id: conversation.id }
  end

  def message
    return render_rate_limited if @conversation.streaming?

    content = params[:content].to_s.strip
    return render_empty_message if content.blank?

    @conversation.add_message!(role: "user", content: content)
    TutorStreamJob.perform_later(@conversation.id)

    render json: { status: "ok" }
  end

  private

  def require_api_key
    return if current_student.api_key.present?

    respond_to do |format|
      format.json do
        render json: {
          error: "Configurez votre cle IA dans les reglages.",
          settings_url: student_settings_path(access_code: params[:access_code])
        }, status: :unprocessable_entity
      end
      format.html do
        redirect_to student_settings_path(access_code: params[:access_code]),
                    alert: "Configurez votre cle IA pour utiliser le tutorat."
      end
    end
  end

  def set_conversation
    @conversation = current_student.conversations.find(params[:id])
  end

  def render_rate_limited
    render json: { error: "Une reponse est deja en cours. Patientez." }, status: :too_many_requests
  end

  def render_empty_message
    render json: { error: "Le message ne peut pas etre vide." }, status: :unprocessable_entity
  end
end
