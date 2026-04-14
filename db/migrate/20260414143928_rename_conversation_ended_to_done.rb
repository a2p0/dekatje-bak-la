class RenameConversationEndedToDone < ActiveRecord::Migration[8.1]
  def up
    execute "UPDATE conversations SET lifecycle_state = 'done' WHERE lifecycle_state = 'ended'"
  end

  def down
    execute "UPDATE conversations SET lifecycle_state = 'ended' WHERE lifecycle_state = 'done'"
  end
end
