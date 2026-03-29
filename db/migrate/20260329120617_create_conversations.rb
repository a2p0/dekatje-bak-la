class CreateConversations < ActiveRecord::Migration[8.1]
  def change
    create_table :conversations do |t|
      t.references :student, null: false, foreign_key: true
      t.references :question, null: false, foreign_key: true
      t.jsonb :messages, default: [], null: false
      t.string :provider_used
      t.integer :tokens_used, default: 0, null: false
      t.boolean :streaming, default: false, null: false
      t.timestamps
    end

    add_index :conversations, [:student_id, :question_id]
  end
end
