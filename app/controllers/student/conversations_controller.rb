class Student::ConversationsController < Student::BaseController
  before_action :require_api_key, only: [ :create, :messages ]
  before_action :set_conversation, only: [ :messages ]

  def create
    @subject = Subject.kept.find(params[:subject_id])

    @conversation = current_student.conversations.find_or_initialize_by(subject: @subject)
    unless @conversation.persisted?
      @conversation.tutor_state = TutorState.default
      @conversation.save!
    end
    @conversation.activate! unless @conversation.active?

    respond_to do |format|
      format.turbo_stream do
        streams = []
        if params[:question_id].present?
          @question_for_drawer = Question.kept.find_by(id: params[:question_id].to_i)
          streams << turbo_stream.replace(
            "tutor-chat-drawer",
            partial: "student/conversations/drawer",
            locals: {
              conversation: @conversation,
              question:     @question_for_drawer || @subject.questions.first,
              access_code:  params[:access_code]
            }
          )
        else
          streams << turbo_stream.replace(
            "tutor-activation-banner",
            partial: "student/tutor/tutor_activated",
            locals: { subject: @subject, access_code: params[:access_code] }
          )
        end
        render turbo_stream: streams
      end
      format.json { render json: { conversation_id: @conversation.id } }
    end
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Sujet introuvable." }, status: :not_found
  rescue AASM::InvalidTransition => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def messages
    content = params[:content].to_s.strip
    return render json: { error: "Le message ne peut pas être vide." }, status: :unprocessable_entity if content.blank?

    question = Question.kept.find(params[:question_id])
    ProcessTutorMessageJob.perform_later(
      @conversation.id,
      content,
      question.id,
      params[:access_code]
    )

    render json: { status: "ok" }
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Question introuvable." }, status: :not_found
  end

  private

  def set_conversation
    @conversation = current_student.conversations.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Conversation introuvable." }, status: :not_found
  end

  def require_api_key
    ResolveTutorApiKey.new(student: current_student, classroom: current_student.classroom).call
  rescue Tutor::NoApiKeyError
    render json: {
      error: "Configurez votre clé IA dans les réglages, ou demandez à votre enseignant d'activer le mode gratuit.",
      settings_url: student_settings_path(access_code: params[:access_code])
    }, status: :unprocessable_entity
  end
end
