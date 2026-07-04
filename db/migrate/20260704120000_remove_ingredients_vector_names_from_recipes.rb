class RemoveIngredientsVectorNamesFromRecipes < ActiveRecord::Migration[8.1]
  def change
    remove_column :recipes, :ingredients_vector_names, :text, array: true, null: false, default: []
  end
end
