class DropQuestionIdFromConversations < ActiveRecord::Migration[8.1]
  def change
    remove_reference :conversations, :question, foreign_key: true, null: true, index: true
  end
end
