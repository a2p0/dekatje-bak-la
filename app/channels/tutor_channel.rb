class TutorChannel < ApplicationCable::Channel
  def subscribed
    conversation = Conversation.find_by(id: params[:conversation_id])

    if conversation && conversation.student_id == current_student&.id
      stream_from "conversation_#{conversation.id}"
    else
      reject
    end
  end

  def unsubscribed
    # Cleanup if needed
  end
end
