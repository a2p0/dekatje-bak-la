class CreateSubjects < ActiveRecord::Migration[8.1]
  def change
    create_table :subjects do |t|
      t.string   :title,             null: false
      t.string   :year,              null: false
      t.integer  :exam_type,         null: false, default: 0
      t.integer  :specialty,         null: false, default: 0
      t.integer  :region,            null: false, default: 0
      t.integer  :status,            null: false, default: 0
      t.text     :presentation_text
      t.datetime :discarded_at
      t.references :owner,           null: false, foreign_key: { to_table: :users }
      t.timestamps
    end

    add_index :subjects, :discarded_at
    add_index :subjects, :status
  end
end
