class ConvertRecipeIngredientNamesToJsonb < ActiveRecord::Migration[8.1]
  def up
    remove_index :recipes, :ingredient_names
    add_column :recipes, :ingredient_names_jsonb, :jsonb, null: false, default: []
    execute "UPDATE recipes SET ingredient_names_jsonb = to_jsonb(ingredient_names)"
    remove_column :recipes, :ingredient_names
    rename_column :recipes, :ingredient_names_jsonb, :ingredient_names
    add_check_constraint :recipes, "jsonb_typeof(ingredient_names) = 'array'", name: "recipes_ingredient_names_json_array"
    add_index :recipes, :ingredient_names, using: :gin
  end

  def down
    remove_index :recipes, :ingredient_names
    remove_check_constraint :recipes, name: "recipes_ingredient_names_json_array"
    add_column :recipes, :ingredient_names_text, :text, array: true, null: false, default: []
    execute <<~SQL.squish
      UPDATE recipes
      SET ingredient_names_text = COALESCE(
        (
          SELECT array_agg(value ORDER BY position)
          FROM jsonb_array_elements_text(ingredient_names) WITH ORDINALITY AS ingredient_name(value, position)
        ),
        ARRAY[]::text[]
      )
    SQL
    remove_column :recipes, :ingredient_names
    rename_column :recipes, :ingredient_names_text, :ingredient_names
    add_index :recipes, :ingredient_names, using: :gin
  end
end
