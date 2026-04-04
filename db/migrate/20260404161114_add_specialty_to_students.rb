class AddSpecialtyToStudents < ActiveRecord::Migration[8.1]
  def change
    add_column :students, :specialty, :integer
  end
end
