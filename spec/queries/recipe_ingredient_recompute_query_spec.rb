require "rails_helper"

RSpec.describe RecipeIngredientRecomputeQuery do
  it "recomputes target recipe ingredient pairs from current recipe names and catalog aliases" do
    tomato = create(:ingredient, name: "tomato", aliases: [ "tomatoes" ])
    pasta = create(:ingredient, name: "pasta")
    stale = create(:ingredient, name: "apple")
    recipe = create(:recipe, ingredient_names: [ "tomatoes", "pasta", "tomatoes", "unknown" ])
    untouched_recipe = create(:recipe, ingredient_names: [ "tomatoes" ])
    create(:recipe_ingredient, recipe:, ingredient: stale)
    create(:recipe_ingredient, recipe: untouched_recipe, ingredient: stale)

    Recipe.connection.exec_query(described_class.call(recipe_ids: [ recipe.id ]), described_class.name)

    expect(recipe.resolved_ingredients.order(:name).pluck(:name)).to eq([ "pasta", "tomato" ])
    expect(untouched_recipe.resolved_ingredients.pluck(:id)).to eq([ stale.id ])
  end

  it "runs one CTE statement for a batch of target recipes" do
    create(:ingredient, name: "lemon")
    recipes = create_list(:recipe, 3, ingredient_names: [ "lemon" ])

    recompute_statements = recorded_sql do
      Recipe.connection.exec_query(described_class.call(recipe_ids: recipes.map(&:id)), described_class.name)
    end.grep(/\AWITH target_recipes AS/)

    expect(recompute_statements.size).to eq(1)
    expect(RecipeIngredient.count).to eq(3)
  end

  def recorded_sql
    statements = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |_name, _started, _finished, _id, payload|
      statements << payload.fetch(:sql) unless payload[:cached] || payload[:name] == "SCHEMA"
    end

    yield
    statements
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end
end
