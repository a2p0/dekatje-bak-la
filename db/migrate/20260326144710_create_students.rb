class CreateStudents < ActiveRecord::Migration[8.1]
  def change
    create_table :students do |t|
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :username, null: false
      t.string :password_digest, null: false
      t.string :encrypted_api_key
      t.string :encrypted_api_key_iv
      t.integer :api_provider, null: false, default: 0
      t.references :classroom, null: false, foreign_key: true
      t.timestamps
    end

    add_index :students, [:username, :classroom_id], unique: true
  end
end
