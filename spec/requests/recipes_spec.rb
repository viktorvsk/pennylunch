require "rails_helper"

RSpec.describe "Recipes", type: :request do
  it "shows an empty index without categories" do
    get recipes_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("No recipe matches yet")
    expect(page_text).to include("Try fewer filters or remove an ingredient from your basket.")
    expect(page_text).not_to include("browse")
    expect(response.body).not_to include("Import recipes")
    expect(h1_texts).to be_empty
    expect(response.body).to include("Category: all categories")
    expect(response.body).to include("Sort: Best Match")
  end

  it "suggests one existing category from an empty filtered result" do
    create(:recipe, title: "Tomato Pasta", category: "Pasta", category_normalized: "pasta")
    create(:recipe, title: "Chicken Soup", category: "Soup", category_normalized: "soup")

    get recipes_path, params: { q: "not-a-real-recipe" }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("No recipe matches yet")
    expect(page_text).to include("browse")
    expect(response.body).to match(%r{href="/recipes/(pasta|soup)"})
    expect(page_text).to match(/Pasta|Soup/)
    expect(response.body).not_to include("Import recipes")
  end

  it "returns 404 when a category query parameter is missing from the catalog" do
    get recipes_path, params: { category: "not-real" }

    expect(response).to have_http_status(:not_found)
  end

  it "returns 404 when a category path is missing from the catalog" do
    get "/recipes/not-real"

    expect(response).to have_http_status(:not_found)
  end

  it "shows mixed recipes without a category heading when category is absent" do
    create(:recipe, title: "Pasta Dinner", category: "Pasta", category_normalized: "pasta")
    create(:recipe, title: "Soup Dinner", category: "Soup", category_normalized: "soup")

    get recipes_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("Pasta Dinner")
    expect(page_text).to include("Soup Dinner")
    expect(h1_texts).to be_empty
    expect(response.body).to include("Category: all categories")
  end

  it "filters recipes through a category path" do
    pasta = create(:recipe, title: "Pasta Dinner", category: "Pasta", category_normalized: "pasta")
    create(:recipe, title: "Soup Dinner", category: "Soup", category_normalized: "soup")

    get "/recipes/pasta"

    expect(response).to have_http_status(:ok)
    expect(h1_texts).to eq([ "Pasta" ])
    expect(page_text).to include("Pasta Dinner")
    expect(page_text).not_to include("Soup Dinner")
    expect(response.body).to include(recipe_path(pasta))
    expect(response.body).to include("Category: Pasta")
  end

  it "filters recipes through a category query parameter" do
    create(:recipe, title: "Pasta Dinner", category: "Pasta", category_normalized: "pasta")
    soup = create(:recipe, title: "Soup Dinner", category: "Soup", category_normalized: "soup")

    get recipes_path, params: { category: "soup" }

    expect(response).to have_http_status(:ok)
    expect(h1_texts).to eq([ "Soup" ])
    expect(page_text).to include("Soup Dinner")
    expect(page_text).not_to include("Pasta Dinner")
    expect(response.body).to include(recipe_path(soup))
    expect(response.body).to include("Category: Soup")
  end

  it "applies title, quick, popular, and selected sort filters" do
    fast = create(:recipe, title: "Fast Weeknight Dinner", prep_time: 5, cook_time: 8, ratings: 4.9)
    slower = create(:recipe, title: "Slower Weeknight Dinner", prep_time: 10, cook_time: 15, ratings: 4.95)
    create(:recipe, title: "Slow Weeknight Dinner", prep_time: 15, cook_time: 45, ratings: 5.0)
    create(:recipe, title: "Low Rated Weeknight Dinner", prep_time: 5, cook_time: 8, ratings: 4.2)
    create(:recipe, title: "Fast Weekend Brunch", prep_time: 5, cook_time: 8, ratings: 5.0)

    get recipes_path, params: { q: "weeknight dinner", quick: "1", popular: "1", sort: "time_asc" }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include(fast.title)
    expect(page_text).to include(slower.title)
    expect(page_text).not_to include("Slow Weeknight Dinner")
    expect(page_text).not_to include("Low Rated Weeknight Dinner")
    expect(page_text).not_to include("Fast Weekend Brunch")
    expect_titles_in_order(fast.title, slower.title)
    expect(response.body).to include("Quick: on")
    expect(response.body).to include("Popular: on")
    expect(response.body).to include("Sort: Fastest First")
  end

  it "filters recipes by selected ingredients and shows readiness" do
    create(:ingredient, name: "avocado", aliases: [ "avocado", "avocados" ])
    create(:ingredient, name: "lime")
    create(:ingredient, name: "rice")
    create(:ingredient, name: "salt", optional: true)
    create(:ingredient, name: "apple")
    simple = create(:recipe, title: "Simple Avocado", ratings: 4.0, ingredient_names: [ "avocados" ])
    bowl = create(:recipe, title: "Avocado Rice Bowl", ratings: 5.0, ingredient_names: [ "avocados", "lime", "rice", "salt" ])
    create(:recipe, title: "Apple Cake", ingredient_names: [ "apple" ])
    sync_recipe_ingredients

    get recipes_path, params: { ingredients: [ "avocado", "lime" ] }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include(simple.title)
    expect(page_text).to include(bowl.title)
    expect(page_text).not_to include("Apple Cake")
    expect_titles_in_order(simple.title, bowl.title)
    expect(page_text).to include("100%")
    expect(page_text).to include("67%")
    expect(response.body).to include("Sort: Best Match")
  end

  it "uses enabled cookie ingredients for the first index render" do
    create(:ingredient, name: "pasta")
    create(:ingredient, name: "garlic")
    create(:ingredient, name: "apple")
    pasta = create(:recipe, title: "Cookie Basket Pasta", ingredient_names: [ "pasta", "garlic" ])
    create(:recipe, title: "Cookie Basket Apple Cake", ingredient_names: [ "apple" ])
    sync_recipe_ingredients

    get recipes_path, headers: { "Cookie" => ingredient_basket_cookie(enabled: true, selected: [ "pasta", "garlic" ]) }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include(pasta.title)
    expect(page_text).not_to include("Cookie Basket Apple Cake")
    expect(page_text).to include("On")
    expect(page_text).to include("only matching recipes are displayed")
  end

  it "keeps explicit ingredient params ahead of cookie ingredients" do
    create(:ingredient, name: "pasta")
    create(:ingredient, name: "garlic")
    create(:recipe, title: "Cookie Param Pasta", ingredient_names: [ "pasta" ])
    garlic = create(:recipe, title: "Cookie Param Garlic", ingredient_names: [ "garlic" ])
    sync_recipe_ingredients

    get recipes_path, params: { ingredients: [ "garlic" ] }, headers: { "Cookie" => ingredient_basket_cookie(enabled: true, selected: [ "pasta" ]) }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include(garlic.title)
    expect(page_text).not_to include("Cookie Param Pasta")
  end

  it "can use real embedding vectors for ingredient search" do
    Rails.cache.write(RecipeIngredientFilterQuery::SEARCH_STRATEGY_CACHE_KEY, RecipeIngredientFilterQuery::VECTOR_SEARCH_STRATEGY)
    create(:ingredient, name: "tomato")
    create(:ingredient, name: "pasta")
    related = create(:recipe, title: "Tomato Spaghetti Sauce", ingredients_vector: LocalEmbedding.call("tomato\nspaghetti\nsauce"))
    create(:recipe, title: "Apple Cinnamon Cake", ingredients_vector: LocalEmbedding.call("apple\ncinnamon\ncake"))

    get recipes_path, params: { ingredients: [ "tomato", "pasta" ] }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include(related.title)
    expect(page_text).not_to include("Apple Cinnamon Cake")
  end

  it "renders only recipe results for Turbo frame requests" do
    create(:recipe, title: "Onion Soup")

    get recipes_path, params: { q: "onion" }, headers: { "Turbo-Frame" => "recipe-results-frame" }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("Onion Soup")
    expect(page_text).not_to include("Market basket")
    expect(page_text).not_to include("Search recipes")
  end

  it "uses infinite scrolling when more recipes are available" do
    create_list(:recipe, RecipesController::PER_PAGE + 1)

    get recipes_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("Loading more recipes")
    expect(page_text).not_to include("#{RecipesController::PER_PAGE + 1} recipes")
    expect(page_text).not_to include("Next")
  end

  it "shows a recipe detail page with parsed ingredients and basket actions" do
    create(:ingredient, name: "tomato", aliases: [ "tomato", "tomatoes" ])
    create(:ingredient, name: "pasta")
    create(:ingredient, name: "salt", optional: true)
    raw_ingredients = [ "2 tomatoes, peeled", "200g pasta", "salt to taste" ]
    parser_result = IngredientParser.call([ raw_ingredients ]).first
    recipe = create(
      :recipe,
      title: "Quick Tomato Pasta",
      prep_time: 5,
      cook_time: 60,
      ratings: 4.59,
      category: "Pasta",
      ingredients: raw_ingredients,
      ingredient_names: parser_result.ingredient_names,
      ingredient_parse_data: parser_result.ingredient_parse_data,
      image: "https://imagesvc.meredithcorp.io/v3/mm/image?url=https%3A%2F%2Fimages.media-allrecipes.com%2Fuserphotos%2F8263243.jpg",
      ingredients_vector: LocalEmbedding.call("tomato\npasta")
    )

    get recipe_path(recipe)

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("Quick Tomato Pasta")
    expect(response.body).to include("https://images.media-allrecipes.com/userphotos/8263243.jpg")
    expect(response.body).to include("href=\"/recipes/pasta\"")
    expect(page_text).to include("1 hour 5 minutes")
    expect(page_text).to include("Ingredients")
    expect(page_text).to include("Main ingredients")
    expect(page_text).to include("2")
    expect(page_text).to include("tomatoes")
    expect(page_text).to include("peeled")
    expect(page_text).to include("200")
    expect(page_text).to include("grams of pasta")
    expect(page_text).to include("salt")
    expect(page_text).to include("to taste")
    expect(page_text).to include("I have it")
  end

  it "shows similar recipes ordered by real vector relevance" do
    recipe = create(:recipe, title: "Tomato Pasta", ingredients_vector: LocalEmbedding.call("tomato\npasta"))
    close = create(:recipe, title: "Tomato Spaghetti Sauce", ingredients_vector: LocalEmbedding.call("tomato\nspaghetti\nsauce"))
    medium = create(:recipe, title: "Tomato Salad", ingredients_vector: LocalEmbedding.call("tomato\nlettuce\nsalad"))
    farther = create(:recipe, title: "Lemon Chicken", ingredients_vector: LocalEmbedding.call("chicken\nlemon"))
    create(:recipe, title: "Unindexed Tomato Soup", ingredients_vector: nil)

    get recipe_path(recipe)

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("Others also view")
    expect(page_text).to include(close.title)
    expect(page_text).to include(medium.title)
    expect(page_text).to include(farther.title)
    expect(page_text).not_to include("Unindexed Tomato Soup")
    expect_titles_in_order(close.title, medium.title, farther.title)
  end

  it "does not show similar recipes for an unindexed recipe" do
    recipe = create(:recipe, title: "Unindexed Tomato Pasta", ingredients_vector: nil)
    create(:recipe, title: "Indexed Tomato Soup", ingredients_vector: LocalEmbedding.call("tomato\nsoup"))

    get recipe_path(recipe)

    expect(response).to have_http_status(:ok)
    expect(page_text).not_to include("Others also view")
    expect(page_text).not_to include("Indexed Tomato Soup")
  end

  it "shows a recipe by trailing id when the friendly URL text is stale" do
    recipe = create(:recipe, title: "Quick Tomato Pasta")

    get "/recipes/stale-friendly-title-#{recipe.id}"

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("Quick Tomato Pasta")
  end

  def page_text
    Nokogiri::HTML(response.body).text.squish
  end

  def h1_texts
    Nokogiri::HTML(response.body).css("h1").map { |node| node.text.squish }
  end

  def expect_titles_in_order(*titles)
    positions = titles.map { |title| response.body.index(title) }
    expect(positions).to all(be_present)
    expect(positions).to eq(positions.sort)
  end

  def sync_recipe_ingredients
    Recipe.connection.exec_query(RecipeIngredientRecomputeQuery.call(recipe_ids: Recipe.ids), RecipeIngredientRecomputeQuery.name)
  end

  def ingredient_basket_cookie(payload)
    "#{ApplicationController::INGREDIENT_BASKET_COOKIE}=#{CGI.escape(payload.to_json)}"
  end
end
