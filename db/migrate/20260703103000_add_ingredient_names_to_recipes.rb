class AddIngredientNamesToRecipes < ActiveRecord::Migration[8.1]
  def change
    add_column :recipes, :ingredient_names, :text, array: true, default: [], null: false
    add_index :recipes, :ingredient_names, using: :gin
  end
end
