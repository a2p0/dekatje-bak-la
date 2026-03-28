class CreateAnswers < ActiveRecord::Migration[8.1]
  def change
    create_table :answers do |t|
      t.text       :correction_text
      t.text       :explanation_text
      t.jsonb      :key_concepts, default: []
      t.jsonb      :data_hints,   default: []
      t.references :question,     null: false, foreign_key: true
      t.timestamps
    end
  end
end
