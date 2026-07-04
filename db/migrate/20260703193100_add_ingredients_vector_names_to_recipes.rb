class AddIngredientsVectorNamesToRecipes < ActiveRecord::Migration[8.1]
  def change
    add_column :recipes, :ingredients_vector_names, :text, array: true, null: false, default: []
  end
end
