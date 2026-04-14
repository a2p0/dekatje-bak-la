class ConversationChannel < ApplicationCable::Channel
  def subscribed
    conversation = Conversation.find_by(id: params[:conversation_id])
    return reject unless conversation && conversation.student == current_student

    stream_from "conversation_#{params[:conversation_id]}"
  end
end
