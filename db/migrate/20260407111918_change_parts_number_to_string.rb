class ChangePartsNumberToString < ActiveRecord::Migration[8.1]
  def up
    change_column :parts, :number, :string, null: false
  end

  def down
    change_column :parts, :number, :integer, null: false
  end
end
