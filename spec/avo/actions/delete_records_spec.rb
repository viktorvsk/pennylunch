require "rails_helper"

RSpec.describe "Avo record actions" do
  include ActiveJob::TestHelper

  it "deletes selected recipe records without deleting ingredients" do
    selected_recipe = create(:recipe)
    retained_recipe = create(:recipe)
    ingredient = create(:ingredient, name: "salt")
    create(:recipe_ingredient, recipe: selected_recipe, ingredient:)

    action = run_action(Avo::Actions::DeleteSelectedRecipes, [ selected_recipe ])

    expect(Recipe.pluck(:id)).to eq([ retained_recipe.id ])
    expect(Ingredient.find_by(id: ingredient.id)).to be_present
    expect(RecipeIngredient.where(recipe_id: selected_recipe.id)).to be_empty
    expect(action.response[:type]).to eq(:reload)
    expect(action.response[:messages]).to include(hash_including(type: :success, body: "Deleted 1 recipe."))
  end

  it "deletes all recipe records in an Avo select-all relation" do
    create(:recipe, category: "Dinner")
    retained_recipe = create(:recipe, category: "Dessert")

    run_action(Avo::Actions::DeleteSelectedRecipes, Recipe.where(category: "Dinner"))

    expect(Recipe.pluck(:id)).to eq([ retained_recipe.id ])
  end

  it "deletes selected ingredient records without deleting recipes" do
    selected_ingredient = create(:ingredient, name: "salt")
    retained_ingredient = create(:ingredient, name: "lemon")
    recipe = create(:recipe)
    create(:recipe_ingredient, recipe:, ingredient: selected_ingredient)

    action = run_action(Avo::Actions::DeleteSelectedIngredients, [ selected_ingredient ])

    expect(Ingredient.pluck(:id)).to eq([ retained_ingredient.id ])
    expect(Recipe.find_by(id: recipe.id)).to be_present
    expect(RecipeIngredient.where(ingredient_id: selected_ingredient.id)).to be_empty
    expect(action.response[:type]).to eq(:reload)
    expect(action.response[:messages]).to include(hash_including(type: :success, body: "Deleted 1 ingredient."))
  end

  it "queues recipe import with the provided URL" do
    action = run_action(Avo::Actions::ImportRecipes, [], fields: { url: "https://example.test/recipes.json.gz" })

    expect(enqueued_jobs.size).to eq(1)
    expect(enqueued_jobs.first[:job]).to eq(ImportRecipesJob)
    expect(enqueued_jobs.first[:args]).to eq([ "https://example.test/recipes.json.gz" ])
    expect(action.response[:type]).to eq(:reload)
    expect(action.response[:messages]).to include(hash_including(type: :success, body: "Queued recipe import."))
  end

  it "keeps the import modal open when the URL is blank" do
    action = run_action(Avo::Actions::ImportRecipes, [], fields: { url: "" })

    expect(enqueued_jobs).to be_empty
    expect(action.response[:type]).to eq(:keep_modal_open)
    expect(action.response[:messages]).to include(hash_including(type: :error, body: "Recipe import URL can't be blank."))
  end

  it "keeps the import modal open when recipes already exist" do
    create(:recipe)

    action = run_action(Avo::Actions::ImportRecipes, [], fields: { url: RecipeImport::DEFAULT_URL })

    expect(enqueued_jobs).to be_empty
    expect(action.response[:type]).to eq(:keep_modal_open)
    expect(action.response[:messages]).to include(hash_including(type: :error, body: "Recipes must be deleted before importing."))
  end

  it "queues selected recipe indexing" do
    selected_recipe = create(:recipe)
    retained_recipe = create(:recipe)

    action = run_action(Avo::Actions::IndexSelectedRecipes, [ selected_recipe ])

    expect(enqueued_jobs.first[:job]).to eq(IndexRecipeJob)
    expect(enqueued_jobs.first[:args]).to eq([ [ selected_recipe.id ] ])
    expect(Recipe.pluck(:id)).to match_array([ selected_recipe.id, retained_recipe.id ])
    expect(action.response[:messages]).to include(hash_including(type: :success, body: "Queued recipe indexing for 1 recipe."))
  end

  it "queues filtered recipe indexing for an Avo relation" do
    dinner = create(:recipe, category: "Dinner")
    create(:recipe, category: "Dessert")

    action = run_action(Avo::Actions::IndexSelectedRecipes, Recipe.where(category: "Dinner"))

    expect(enqueued_jobs.first[:job]).to eq(IndexRecipeJob)
    expect(enqueued_jobs.first[:args]).to eq([ [ dinner.id ] ])
    expect(action.response[:messages]).to include(hash_including(type: :success, body: "Queued recipe indexing for 1 recipe."))
  end

  it "queues full recipe indexing for an unfiltered Avo select-all relation" do
    create_list(:recipe, 2)

    action = run_action(Avo::Actions::IndexSelectedRecipes, Recipe.all)

    expect(enqueued_jobs.first[:job]).to eq(IndexRecipeJob)
    expect(enqueued_jobs.first[:args]).to eq([ "all" ])
    expect(action.response[:messages]).to include(hash_including(type: :success, body: "Queued recipe indexing for all recipes."))
  end

  it "keeps recipe indexing modal open when no recipes are selected" do
    action = run_action(Avo::Actions::IndexSelectedRecipes, [])

    expect(enqueued_jobs).to be_empty
    expect(action.response[:type]).to eq(:keep_modal_open)
    expect(action.response[:messages]).to include(hash_including(type: :error, body: "Select at least one recipe."))
  end

  it "updates recipe search strategy in-place" do
    cache = ActiveSupport::Cache::MemoryStore.new
    allow(Rails).to receive(:cache).and_return(cache)

    action = run_action(Avo::Actions::SetRecipeSearchStrategy, [], fields: { strategy: "vector" })

    expect(cache.read("search_strategy")).to eq("vector")
    expect(action.response[:messages]).to include(hash_including(type: :success, body: "Updated recipe search strategy to vector."))
  end

  it "keeps the search strategy modal open when the strategy is invalid" do
    cache = ActiveSupport::Cache::MemoryStore.new
    allow(Rails).to receive(:cache).and_return(cache)

    action = run_action(Avo::Actions::SetRecipeSearchStrategy, [], fields: { strategy: "naive_vector_search" })

    expect(cache.read("search_strategy")).to be_nil
    expect(action.response[:type]).to eq(:keep_modal_open)
    expect(action.response[:messages]).to include(hash_including(type: :error, body: "Unknown recipe search strategy."))
  end

  it "queues ingredient catalog bootstrap" do
    action = run_action(Avo::Actions::BootstrapIngredients, [])

    expect(enqueued_jobs.first[:job]).to eq(BootstrapIngredientsJob)
    expect(enqueued_jobs.first[:args]).to eq([])
    expect(action.response[:messages]).to include(hash_including(type: :success, body: "Queued ingredient catalog bootstrap."))
  end

  def run_action(action_class, query, fields: {})
    action = action_class.new
    relation =
      case query
      when ActiveRecord::Relation
        query
      when Array
        model_class = action_class.to_s.include?("Ingredient") ? Ingredient : Recipe
        model_class.where(id: query.map { |item| item.respond_to?(:id) ? item.id : item })
      else
        Recipe.all
      end
    action.handle(query: relation, fields:, current_user: nil, resource: nil)
    action
  end
end
