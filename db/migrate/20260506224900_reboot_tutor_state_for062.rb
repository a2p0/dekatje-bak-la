class RebootTutorStateFor062 < ActiveRecord::Migration[8.1]
  def up
    # 062: complete reset of tutor_state JSONB.
    # Conversations and Messages are kept; only the JSONB blob is wiped so that
    # the new TutorStateType can hydrate fresh state on first read.
    Conversation.in_batches(of: 500) do |batch|
      batch.update_all(tutor_state: {})
    end

    # AASM trims: validating/feedback removed in 062. Map them to active so
    # existing rows match the new state machine.
    Conversation.where(lifecycle_state: %w[validating feedback])
                .update_all(lifecycle_state: "active")
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
