class CreateExamSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :exam_sessions do |t|
      t.string :title, null: false
      t.string :year, null: false
      t.integer :region, null: false, default: 0
      t.integer :exam_type, null: false, default: 0
      t.text :presentation_text
      t.references :owner, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :exam_sessions, [:owner_id, :year, :region], name: "idx_exam_sessions_lookup"
  end
end
