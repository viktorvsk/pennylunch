require "yaml"

class BootstrapIngredients < ApplicationJob
  queue_as :default

  CATALOG_PATH = Rails.root.join("config/ingredient_aliases.yml")

  def perform(path = CATALOG_PATH.to_s)
    ingredients = YAML.safe_load_file(path.to_s)["ingredients"]
    rows = ingredients.map do |name, attributes|
      {
        name:,
        aliases: attributes["aliases"],
        optional: attributes["optional"] || false
      }
    end

    Ingredient.upsert_all(rows, unique_by: :index_ingredients_on_name, record_timestamps: true)

    ingredients.size
  end
end
