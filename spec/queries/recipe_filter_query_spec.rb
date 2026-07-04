require "rails_helper"

RSpec.describe RecipeFilterQuery do
  it "applies title, category, quick, popular, and ingredient filters" do
    create(:ingredient, name: "tomato")
    match = create(:recipe, title: "Tomato Dinner", category: "Dinner", prep_time: 10, cook_time: 15, ratings: 4.9, ingredient_names: [ "tomato" ])
    create(:recipe, title: "Tomato Dessert", category: "Dessert", prep_time: 10, cook_time: 15, ratings: 4.9, ingredient_names: [ "tomato" ])
    create(:recipe, title: "Slow Tomato Dinner", category: "Dinner", prep_time: 20, cook_time: 20, ratings: 4.9, ingredient_names: [ "tomato" ])
    create(:recipe, title: "Low Rated Tomato Dinner", category: "Dinner", prep_time: 10, cook_time: 15, ratings: 4.0, ingredient_names: [ "tomato" ])
    create(:recipe, title: "Garlic Dinner", category: "Dinner", prep_time: 10, cook_time: 15, ratings: 4.9, ingredient_names: [ "garlic" ])
    create_recipe_ingredient_rows

    result = described_class.call(
      filters: {
        "q" => "tomato",
        "category" => "Dinner",
        "quick" => "1",
        "popular" => "1",
        "ingredients" => "tomato"
      }
    )

    expect(result).to eq([ match ])
  end

  def create_recipe_ingredient_rows
    ingredient_ids_by_name = Ingredient.pluck(:name, :id).to_h
    metadata = IngredientCatalogMetadata.call

    Recipe.find_each do |recipe|
      recipe.ingredient_names.filter_map do |raw_name|
        record = metadata[Ingredient.normalize_lookup_key(raw_name)]
        ingredient_ids_by_name[record.name] if record
      end.uniq.each do |ingredient_id|
        RecipeIngredient.find_or_create_by!(recipe:, ingredient_id:)
      end
    end
  end
end
