class AddAliasIndexToIngredients < ActiveRecord::Migration[8.1]
  def change
    add_index :ingredients, :aliases, using: :gin
  end
end
