class AddKindToMessages < ActiveRecord::Migration[8.1]
  def change
    add_column :messages, :kind, :integer, default: 0, null: false
  end
end
