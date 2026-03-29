class AddTutorPromptTemplateToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :tutor_prompt_template, :text
  end
end
