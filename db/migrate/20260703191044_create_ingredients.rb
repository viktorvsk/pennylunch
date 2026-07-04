class CreateIngredients < ActiveRecord::Migration[8.1]
  def change
    create_table :ingredients do |t|
      t.string :name, null: false
      t.jsonb :aliases, null: false, default: []

      t.timestamps
    end

    add_index :ingredients, :name, unique: true
    add_check_constraint :ingredients, "jsonb_typeof(aliases) = 'array'", name: "ingredients_aliases_json_array"
  end
end
