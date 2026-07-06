class BootstrapIngredientsJob < ApplicationJob
  CATALOG_PATH = Rails.root.join("config/ingredient_aliases.yml")

  def perform
    ingredients = YAML.safe_load_file(CATALOG_PATH)["ingredients"]
    rows = ingredients.map do |name, attributes|
      {
        name:,
        aliases: attributes["aliases"],
        optional: attributes.fetch("optional", false)
      }
    end

    Ingredient.upsert_all(rows, unique_by: :name, record_timestamps: true)
  end
end
