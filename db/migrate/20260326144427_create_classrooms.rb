class CreateClassrooms < ActiveRecord::Migration[8.1]
  def change
    create_table :classrooms do |t|
      t.string :name, null: false
      t.string :school_year, null: false
      t.string :specialty
      t.string :access_code, null: false
      t.references :owner, null: false, foreign_key: { to_table: :users }
      t.timestamps
    end

    add_index :classrooms, :access_code, unique: true
  end
end
