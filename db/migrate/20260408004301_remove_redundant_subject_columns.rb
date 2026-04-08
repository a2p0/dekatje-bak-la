class RemoveRedundantSubjectColumns < ActiveRecord::Migration[8.1]
  def change
    remove_column :subjects, :title, :string
    remove_column :subjects, :year, :string
    remove_column :subjects, :exam_type, :integer
    remove_column :subjects, :region, :integer
  end
end
