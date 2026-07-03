class AddIngredientParseDataToRecipes < ActiveRecord::Migration[8.1]
  def change
    add_column :recipes, :ingredient_parse_data, :jsonb, default: [], null: false
  end
end
