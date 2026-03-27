class CreateQuestions < ActiveRecord::Migration[8.1]
  def change
    create_table :questions do |t|
      t.string     :number,       null: false
      t.text       :label,        null: false
      t.text       :context_text
      t.decimal    :points
      t.integer    :answer_type,  null: false, default: 0
      t.integer    :position,     null: false, default: 0
      t.integer    :status,       null: false, default: 0
      t.datetime   :discarded_at
      t.references :part,         null: false, foreign_key: true
      t.timestamps
    end

    add_index :questions, :discarded_at
    add_index :questions, [ :part_id, :position ]
  end
end
