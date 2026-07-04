class AddOptionalToIngredients < ActiveRecord::Migration[8.1]
  def change
    add_column :ingredients, :optional, :boolean, null: false, default: false
    add_index :ingredients, :optional
  end
end
