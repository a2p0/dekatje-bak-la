class CreateParts < ActiveRecord::Migration[8.1]
  def change
    create_table :parts do |t|
      t.integer    :number,        null: false
      t.string     :title,         null: false
      t.text       :objective_text
      t.integer    :section_type,  null: false, default: 0
      t.integer    :position,      null: false, default: 0
      t.references :subject,       null: false, foreign_key: true
      t.timestamps
    end

    add_index :parts, [ :subject_id, :position ]
  end
end
