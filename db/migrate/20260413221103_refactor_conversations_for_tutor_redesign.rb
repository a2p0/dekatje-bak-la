class RefactorConversationsForTutorRedesign < ActiveRecord::Migration[8.1]
  def change
    # NOTE: this migration assumes no Conversation rows exist when it runs.
    # On dev, the table was manually purged before migrating. On Neon prod,
    # no real user conversations exist yet. If a future environment has data,
    # a backfill for subject_id must be added before `add_reference ... null: false`.

    # Remove old JSONB message store and streaming flag
    remove_column :conversations, :messages, :jsonb, default: [], null: false
    remove_column :conversations, :streaming, :boolean, default: false, null: false

    # Remove old per-question unique index before changing the FK
    remove_index :conversations, column: [ :student_id, :question_id ],
                 name: "index_conversations_on_student_id_and_question_id"

    # Change question_id from NOT NULL FK to nullable (conversations no longer
    # belong directly to a question — messages carry the question reference)
    change_column_null :conversations, :question_id, true

    # Add subject reference (the new root association)
    add_reference :conversations, :subject, null: false, foreign_key: true,
                  index: true

    # Add AASM lifecycle column
    add_column :conversations, :lifecycle_state, :string,
               null: false, default: "disabled"

    # Add typed TutorState column (JSONB, serialised by TutorStateType)
    add_column :conversations, :tutor_state, :jsonb, null: false, default: {}

    # New unique index: one conversation per (student, subject)
    add_index :conversations, [ :student_id, :subject_id ], unique: true,
              name: "index_conversations_on_student_id_and_subject_id"
  end
end
