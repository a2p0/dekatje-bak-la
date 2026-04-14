class CreateMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :messages do |t|
      t.references :conversation, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.integer    :role,         null: false                    # enum: user/assistant/system
      t.text       :content,      null: false
      t.bigint     :question_id,  null: true                     # nullable: context link
      t.integer    :tokens_in,    default: 0, null: false
      t.integer    :tokens_out,   default: 0, null: false
      t.integer    :chunk_index,  default: 0, null: false
      t.datetime   :streaming_finished_at
      t.timestamps

      t.index [ :conversation_id, :created_at ]
    end

    add_foreign_key :messages, :questions, column: :question_id, on_delete: :nullify
    add_index :messages, :question_id
  end
end
