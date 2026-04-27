class AllowNullSpecialtyOnSubjects < ActiveRecord::Migration[8.1]
  def change
    change_column_null :subjects, :specialty, true
    change_column_default :subjects, :specialty, nil
  end
end
