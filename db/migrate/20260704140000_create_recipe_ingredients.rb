class CreateRecipeIngredients < ActiveRecord::Migration[8.1]
  def change
    create_table :recipe_ingredients do |t|
      t.references :recipe, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.references :ingredient, null: false, foreign_key: { on_delete: :cascade }, index: false

      t.timestamps
    end

    add_index :recipe_ingredients, [ :recipe_id, :ingredient_id ], unique: true
    add_index :recipe_ingredients, [ :ingredient_id, :recipe_id ]
  end
end
