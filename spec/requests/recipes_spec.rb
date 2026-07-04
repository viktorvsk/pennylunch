require "rails_helper"

RSpec.describe "Recipes", type: :request do
  it "shows an empty index" do
    get recipes_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("No recipe matches yet")
    expect(response.body).to include("M8 16a5 5 0 0 1 8 0")
    expect(response.body).not_to include("Import recipes")
    expect(response.body).not_to include("<h1")
  end

  it "advertises the web app icon set" do
    get recipes_path

    document = Nokogiri::HTML(response.body)
    png_icons = document.css("link[rel='icon'][type='image/png']").map { |link| [ link["href"], link["sizes"] ] }

    expect(document.at_css("link[rel='manifest']")["href"]).to eq("/manifest.json")
    expect(document.at_css("link[rel='icon'][href='/favicon.ico'][sizes='any']")).not_to be_nil
    expect(document.at_css("link[rel='icon'][href='/pen.svg'][type='image/svg+xml']")).not_to be_nil
    expect(png_icons).to include(
      [ "/favicon-16x16.png", "16x16" ],
      [ "/favicon-32x32.png", "32x32" ],
      [ "/favicon-48x48.png", "48x48" ],
      [ "/icon-64x64.png", "64x64" ],
      [ "/icon-192x192.png", "192x192" ],
      [ "/icon-512x512.png", "512x512" ]
    )
    expect(document.at_css("link[rel='apple-touch-icon'][href='/apple-touch-icon.png'][sizes='180x180']")).not_to be_nil
    expect(document.at_css("meta[name='theme-color']")["content"]).to eq("#dc3f2f")
  end

  it "filters recipes and links to the show page" do
    create(:ingredient, name: "tomato", optional: true)
    create(:ingredient, name: "pasta")
    recipe = create(
      :recipe,
      title: "Quick Tomato Pasta",
      category: "Pasta",
      category_normalized: "pasta",
      ingredient_names: [ "tomato", "pasta", "garlic" ],
      ratings: 4.95
    )
    create(:recipe, title: "Slow Roast Chicken", category: "Dinner", category_normalized: "dinner")
    create(:recipe, title: "Crispy Fish", category: "Air Fryer Main Dish Recipes", category_normalized: "air fryer main dish recipes")

    get "/recipes/pasta", params: { q: "tomato", popular: "1", sort: "rating_desc" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Quick Tomato Pasta")
    expect(response.body).not_to include("Slow Roast Chicken")
    expect(response.body).to include(recipe_path(recipe))
    document = Nokogiri::HTML(response.body)
    expect(document.css("a[href='#{recipe_path(recipe)}'][data-turbo-frame='_top']").size).to eq(2)
    expect(document.css("a[href='/recipes/pasta'][data-turbo-frame='_top']")).not_to be_empty
    expect(document.at_css("div[role='option'][data-value='air fryer main dish recipes'][data-label='Air Fryer Main Dish Recipes']").text).to eq("Air Fryer Main Dish Recipes")
    expect(response.body).to include("data-tooltip=\"Rating: 4.95 out of 5\"")
    expect(response.body).to include("data-tooltip=\"Prepare for 10 minutes then cook for 20 minutes\"")
    expect(response.body).to include("href=\"/recipes/pasta\"")
    expect(response.body).to include("tomato, pasta, garlic")
    ingredient_summary = document.at_css("[data-ingredient-matches-target='summary']")
    expect(JSON.parse(ingredient_summary["data-recipe-ingredients"])).to eq([
      { "name" => "tomato", "matchName" => "tomato" },
      { "name" => "pasta", "matchName" => "pasta" },
      { "name" => "garlic", "matchName" => nil }
    ])
    expect(recipe_catalog_from(document)).to include(
      "categoryLabels" => hash_including("air fryer main dish recipes" => "Air Fryer Main Dish Recipes"),
      "categorySlugs" => hash_including("pasta" => "pasta")
    )
    expect(recipe_catalog_from(document).fetch("ingredientOptions")).to include(
      { "name" => "tomato", "optional" => true },
      { "name" => "pasta", "optional" => false }
    )
    expect(document.at_css("a[href='/recipes']").text).to eq("PennyLunch")
    expect(document.css("[role='switch']")).not_to be_empty
    expect(document.css("[role='combobox']")).not_to be_empty
    expect(document.css(".dropdown-menu")).not_to be_empty
    expect(response.body).to include("data-tooltip=\"Category: Pasta\"")
    expect(document.css(".recipe-toolbar")).not_to be_empty
    expect(response.body).to include("recipe-content-loading")
    expect(response.body).not_to include("recipe-toolbar-loading")
    expect(response.body).to include("type=\"importmap\"")
    expect(response.body).to include("data-controller=\"auto-submit\"")
    expect(response.body).to include("data-auto-submit-target=\"ingredients\"")
    expect(response.body).to include("id=\"recipe-results-frame\"")
    expect(response.body).to include("id=\"recipe-ingredients-fab\"")
    expect(response.body).to include("data-turbo-permanent")
    expect(response.body).to include("data-controller=\"ingredients-fab\"")
    expect(response.body).to include("Search recipes")
    expect(response.body).to include("Market basket")
    expect(response.body).to include("Add what is in your kitchen. Matching recipes move to the front.")
    expect(response.body).to include("Tomato, eggs, parsley...")
    expect(response.body).to include("aria-label=\"Scan photo or image URL\"")
    expect(response.body).to include("id=\"recipe-ingredients-image-dialog\"")
    expect(response.body).to include("Pen can fill your basket from a photo.")
    expect(response.body).to include("You can also paste an image URL.")
    expect(response.body).to include("Drop a photo here")
    expect(response.body).to include("or paste an image URL")
    expect(response.body).to include("Reading your photo...")
    expect(response.body).to include("action=\"/ingredient_image\"")
    expect(response.body).to include("name=\"image[file]\"")
    expect(response.body).to include("name=\"image[url]\"")
    expect(response.body).not_to include(">Read image<")
    expect(response.body).not_to include("—")
    expect(response.body).to include("you see all recipes.")
    expect(response.body).not_to include("Pick matching ingredients. Enable to include them in filters.")
    expect(document.css("label[for='recipe-ingredients-input']")).to be_empty
    expect(document.css("[data-ingredients-filter-help]")).to be_empty
    expect(document.css("[data-ingredients-fab-target='addButton']")).to be_empty
    expect(response.body).not_to include("Add Ingredient")
    expect(response.body).to include("data-recipe-catalog")
    expect(response.body).not_to include("data-ingredient-options")
    expect(response.body).to include("data-ingredients-fab-target=\"input\"")
    expect(response.body).to include("data-ingredients-fab-target=\"selectedList\"")
    expect(response.body).to include("tomato")
    expect(response.body).not_to include("data-ingredients-filter-textarea")
    expect(document.at_css("h1").text).to eq("Pasta")
    expect(response.body).to include("aria-label=\"Admin\"")
    expect(response.body).not_to include("Show recipes")
    expect(response.body).not_to include(">Clear<")
    expect(response.body).not_to include(">Admin<")
  end

  it "renders infinite scroll instead of totals and pagination links" do
    create_list(:recipe, RecipesController::PER_PAGE + 1)

    get recipes_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("id=\"recipe-results\"")
    expect(response.body).to include("data-controller=\"infinite-scroll\"")
    expect(response.body).to include("data-infinite-scroll-next-url-value=\"/recipes?page=2\"")
    expect(response.body).to include("infinite-scroll-spinner")
    expect(response.body).not_to include("#{RecipesController::PER_PAGE + 1} recipes")
    expect(response.body).not_to include(">Next<")
  end

  it "renders recipe card durations as human-friendly text" do
    create(:recipe, title: "Slow Sunday Pasta", prep_time: 5, cook_time: 60)

    get recipes_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("1 hour 5 minutes")
    expect(response.body).not_to include(">65 min<")
  end

  it "renders only the results frame for Turbo frame filter requests" do
    create(:recipe, title: "Onion Soup")

    get recipes_path, params: { q: "onion" }, headers: { "Turbo-Frame" => "recipe-results-frame" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("id=\"recipe-results-frame\"")
    expect(response.body).to include("Onion Soup")
    expect(response.body).not_to include("recipe-toolbar")
    expect(response.body).not_to include("recipe-content-loading")
    expect(response.body).not_to include("recipe-ingredients-fab")
    expect(response.body).not_to include("data-ingredient-options")
    expect(response.body).not_to include("data-recipe-catalog")
  end

  it "suggests a category from the empty state when filters find no recipes" do
    create(:recipe, category: "Pasta", category_normalized: "pasta")

    get recipes_path, params: { q: "not-a-real-title" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("No recipe matches yet")
    expect(response.body).to include("href=\"/recipes/pasta\"")
    expect(response.body).not_to include("Import recipes")
  end

  it "filters query category params without redirecting" do
    create(:recipe, title: "Tomato Pasta", category: "Pasta", category_normalized: "pasta")
    create(:recipe, title: "Tomato Soup", category: "Soup", category_normalized: "soup")

    get recipes_path, params: { q: "tomato", category: "pasta", sort: "rating_desc" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Tomato Pasta")
    expect(response.body).not_to include("Tomato Soup")
  end

  it "returns 404 when category query parameter is invalid" do
    get recipes_path, params: { category: "not-real" }
    expect(response).to have_http_status(:not_found)
  end

  it "returns 404 when category path parameter is invalid" do
    get "/recipes/not-real"
    expect(response).to have_http_status(:not_found)
  end

  it "applies quick filtering and selected sorting" do
    low_rated_quick = create(:recipe, title: "Low Rated Quick Dinner", prep_time: 5, cook_time: 10, ratings: 4.1)
    high_rated_quick = create(:recipe, title: "High Rated Quick Dinner", prep_time: 7, cook_time: 12, ratings: 4.9)
    create(:recipe, title: "Slow Weekend Dinner", prep_time: 20, cook_time: 90, ratings: 5.0)

    get recipes_path, params: { quick: "1", sort: "rating_desc" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(high_rated_quick.title, low_rated_quick.title)
    expect(response.body).not_to include("Slow Weekend Dinner")
    expect(response.body.index(high_rated_quick.title)).to be < response.body.index(low_rated_quick.title)
  end

  it "filters recipes by available ingredients through ingredient overlap search" do
    create(:ingredient, name: "pasta")
    create(:ingredient, name: "garlic")
    create(:ingredient, name: "olive oil")
    pasta = create(:recipe, title: "Pasta and Garlic", ingredient_names: [ "pasta", "garlic", "olive oil" ], ingredients_vector: vector(1.0))
    create(:recipe, title: "Apple Cake", ingredients_vector: vector(-1.0))
    create_recipe_ingredient_rows
    allow(IngredientParser).to receive(:call)

    ingredient_filter = [ "pasta", "garlic", "olive oil" ]

    get recipes_path, params: { ingredients: ingredient_filter, sort: "rating_desc" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Pasta and Garlic")
    expect(response.body).not_to include("Apple Cake")
    expect(response.body).to include(recipe_path(pasta))
    document = Nokogiri::HTML(response.body)
    expect(document.css("input[name='ingredients[]']").map { |input| input["value"] }).to eq(ingredient_filter)
    expect(JSON.parse(document.at_css("#recipe-ingredients-fab")["data-ingredients-fab-current-ingredients-value"])).to eq(ingredient_filter)
    expect(IngredientParser).not_to have_received(:call)
  end

  it "uses an enabled ingredient basket cookie for the first index render" do
    create(:ingredient, name: "pasta")
    create(:ingredient, name: "garlic")
    pasta = create(:recipe, title: "Cookie Basket Pasta", ingredient_names: [ "pasta", "garlic" ])
    create(:recipe, title: "Cookie Basket Apple Cake", ingredient_names: [ "apple" ])
    create_recipe_ingredient_rows

    get recipes_path, headers: { "Cookie" => ingredient_basket_cookie(enabled: true, selected: [ "pasta", "garlic" ]) }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Cookie Basket Pasta")
    expect(response.body).not_to include("Cookie Basket Apple Cake")
    expect(response.body).to include(recipe_path(pasta))
    document = Nokogiri::HTML(response.body)
    expect(JSON.parse(document.at_css("#recipe-ingredients-fab")["data-ingredients-fab-current-ingredients-value"])).to eq([ "pasta", "garlic" ])
  end

  it "keeps explicit ingredient params ahead of the ingredient basket cookie" do
    create(:ingredient, name: "pasta")
    create(:ingredient, name: "garlic")
    create(:recipe, title: "Cookie Param Pasta", ingredient_names: [ "pasta" ])
    garlic = create(:recipe, title: "Cookie Param Garlic", ingredient_names: [ "garlic" ])
    create_recipe_ingredient_rows

    get recipes_path, params: { ingredients: [ "garlic" ] }, headers: { "Cookie" => ingredient_basket_cookie(enabled: true, selected: [ "pasta" ]) }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Cookie Param Garlic")
    expect(response.body).not_to include("Cookie Param Pasta")
    expect(response.body).to include(recipe_path(garlic))
  end

  it "defaults ingredient searches to fewest visible missing ingredients order" do
    create(:ingredient, name: "avocado", aliases: [ "avocados" ])
    create(:ingredient, name: "lime")
    create(:ingredient, name: "rice")
    simple_avocado = create(:recipe, title: "Simple Avocado", ratings: 4.0, ingredient_names: [ "avocados" ])
    avocado_rice_bowl = create(:recipe, title: "Avocado Rice Bowl", ratings: 5.0, ingredient_names: [ "avocados", "lime", "rice" ])
    create_recipe_ingredient_rows

    get recipes_path, params: { ingredients: [ "avocado", "lime" ] }

    expect(response).to have_http_status(:ok)
    expect(response.body.index(simple_avocado.title)).to be < response.body.index(avocado_rice_bowl.title)
    expect(response.body).to include("data-tooltip=\"Sort: Best Match\"")
    expect(response.body).to include(">Best Match<")
  end

  it "shows required ingredient readiness in recipe card footers" do
    create(:ingredient, name: "avocado", aliases: [ "avocados" ])
    create(:ingredient, name: "lime")
    create(:ingredient, name: "rice")
    create(:ingredient, name: "salt", optional: true)
    recipe = create(:recipe, title: "Avocado Rice Bowl", ingredient_names: [ "avocados", "lime", "rice", "salt" ])
    create_recipe_ingredient_rows

    get recipes_path, params: { ingredients: [ "avocado", "lime" ] }

    document = Nokogiri::HTML(response.body)
    card = document.css(".recipe-card").find { |node| node.text.include?(recipe.title) }
    readiness = card.at_css("[data-ingredient-matches-target='readiness']")

    expect(readiness.text.squish).to eq("67%")
    expect(JSON.parse(readiness["data-required-ingredient-names"])).to eq([ "avocado", "lime", "rice" ])
    expect(readiness["data-tooltip"]).to eq("Matches 2 of 3 required ingredients in your selected ingredients. Pantry staples are not counted.")
    expect(readiness["data-state"]).to eq("partial")
  end

  it "applies best matching order to vector search candidates" do
    allow(Rails.cache).to receive(:read).and_call_original
    allow(Rails.cache).to receive(:read).with("search_strategy").and_return("vector")
    create(:ingredient, name: "avocado", aliases: [ "avocados" ])
    create(:ingredient, name: "lime")
    create(:ingredient, name: "rice")
    simple_avocado = create(:recipe, title: "Simple Avocado", ratings: 4.0, ingredient_names: [ "avocados" ], ingredients_vector: vector(1.0))
    avocado_rice_bowl = create(:recipe, title: "Avocado Rice Bowl", ratings: 5.0, ingredient_names: [ "avocados", "lime", "rice" ], ingredients_vector: vector(0.9, 0.1))
    create(:recipe, title: "Apple Cake", ingredient_names: [ "apple" ], ingredients_vector: vector(-1.0))
    create_recipe_ingredient_rows
    allow(IngredientParser).to receive(:call)
    allow(LocalEmbedding).to receive(:call).and_return(vector(1.0))

    get recipes_path, params: { ingredients: [ "avocado", "lime" ] }

    expect(response).to have_http_status(:ok)
    expect(response.body.index(simple_avocado.title)).to be < response.body.index(avocado_rice_bowl.title)
    expect(response.body).not_to include("Apple Cake")
    expect(IngredientParser).not_to have_received(:call)
  end

  it "shows a recipe and its ingredients" do
    create(:ingredient, name: "tomato", aliases: [ "tomatoes" ])
    create(:ingredient, name: "pasta")
    recipe = create(
      :recipe,
      title: "Quick Tomato Pasta",
      prep_time: 0,
      cook_time: 0,
      ratings: 4.59,
      category: "Pasta",
      ingredients: [ "2 tomatoes", "200g pasta" ],
      ingredients_vector: vector(1.0),
      ingredient_parse_data: [
        {
          "input" => "2 tomatoes",
          "parser" => {
            "amount" => [ { "quantity" => "2", "unit" => nil } ],
            "name" => [ { "text" => "tomatoes" } ],
            "preparation" => "peeled"
          }
        },
        {
          "input" => "200g pasta",
          "parser" => {
            "amount" => [ { "quantity" => "200", "unit" => "g" } ],
            "name" => [ { "text" => "pasta" } ]
          }
        }
      ],
      image: "https://imagesvc.meredithcorp.io/v3/mm/image?url=https%3A%2F%2Fimages.media-allrecipes.com%2Fuserphotos%2F8263243.jpg"
    )
    similar_titles = [
      create(:recipe, title: "Tomato Soup", category: "Soup", ingredients_vector: vector(0.98, 0.02)).title,
      create(:recipe, title: "Tomato Salad", category: "Salad", ingredients_vector: vector(0.9, 0.1)).title,
      create(:recipe, title: "Tomato Bruschetta", category: "Appetizers", ingredients_vector: vector(0.8, 0.2)).title
    ]
    create(:recipe, title: "Same Category Without Vector", category: "Pasta", ingredients_vector: nil)
    create(:recipe, title: "Distant Pasta", category: "Pasta", ingredients_vector: vector(-1.0))

    get recipe_path(recipe)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Quick Tomato Pasta")
    expect(response.body).to include("https://images.media-allrecipes.com/userphotos/8263243.jpg")
    expect(response.body).to include("data-tooltip=\"Rating: 4.59 out of 5\"")
    document = Nokogiri::HTML(response.body)
    expect(document.css("span").map { |node| node.text.squish }).not_to include("0 min")
    expect(response.body).to include("href=\"/recipes\"")
    expect(response.body).to include("href=\"/recipes/pasta\"")
    expect(document.css(".recipe-toolbar")).not_to be_empty
    expect(response.body).to include("aria-label=\"Admin\"")
    expect(response.body).to include("recipe-show-card")
    expect(response.body).to include("Ingredients")
    expect(response.body).to include("2")
    expect(response.body).to include("200")
    expect(response.body).to include("g")
    expect(response.body).to include("peeled")
    ingredient_links = document.css(".recipe-ingredient-link").map { |node| [ node.text.squish, node["href"], node["target"], node["rel"] ] }
    expect(ingredient_links).to include([ "tomatoes", "https://en.wikipedia.org/wiki/tomatoes", "_blank", "noopener" ])
    expect(document.css(".recipe-ingredient-link[data-ingredient-name]").map { |node| node["data-ingredient-name"] }).to include("tomatoes", "pasta")
    ingredient_action = document.at_css(".recipe-ingredient-row:has(.recipe-ingredient-link[data-ingredient-name='tomatoes']) .recipe-ingredient-basket-button")
    expect(ingredient_action.text.squish).to eq("I have it")
    expect(ingredient_action["type"]).to eq("button")
    expect(ingredient_action["data-action"]).to eq("click->ingredient-matches#addToBasket")
    expect(ingredient_action["data-ingredient-basket-name"]).to eq("tomato")
    remove_action = document.at_css(".recipe-ingredient-row:has(.recipe-ingredient-link[data-ingredient-name='tomatoes']) .recipe-ingredient-match-icon")
    expect(remove_action.name).to eq("button")
    expect(remove_action["type"]).to eq("button")
    expect(remove_action["data-action"]).to eq("click->ingredient-matches#removeFromBasket")
    expect(remove_action["data-ingredient-basket-remove"]).to eq("")
    expect(remove_action["data-ingredient-basket-name"]).to eq("tomato")
    expect(remove_action["disabled"]).to eq("disabled")
    expect(response.body).to include("Similar recipes")
    similar_titles.each { |title| expect(response.body).to include(title) }
    expect(response.body).not_to include("Same Category Without Vector")
    expect(response.body).not_to include("Distant Pasta")
    expect(response.body).not_to include("aria-label=\"Breadcrumb\"")
    expect(response.body).to include("role=\"switch\"")
    expect(response.body).to include("role=\"combobox\"")
    expect(response.body).to include("id=\"recipe-ingredients-fab\"")
    expect(response.body.index("<h1")).to be < response.body.index("<img")
  end

  it "groups recipe ingredients by optional ingredient metadata" do
    create(:ingredient, name: "tomato")
    create(:ingredient, name: "salt", optional: true)
    recipe = create(
      :recipe,
      title: "Tomato Plate",
      ingredients: [ "1 tomato", "salt to taste", "house seasoning" ],
      ingredient_names: [ "tomato", "salt", "house seasoning" ],
      ingredient_parse_data: [
        { "parser" => { "name" => [ { "text" => "tomato" } ] } },
        { "parser" => { "name" => [ { "text" => "salt" } ] } },
        { "parser" => { "name" => [ { "text" => "house seasoning" } ] } }
      ]
    )

    get recipe_path(recipe)

    document = Nokogiri::HTML(response.body)
    groups = document.css(".recipe-ingredient-group").map do |group|
      [
        group.at_css("h3").text.squish,
        group.css(".recipe-ingredient-link").map { |node| node.text.squish }
      ]
    end
    expect(groups).to eq([
      [ "Main ingredients", [ "tomato", "house seasoning" ] ],
      [ "Pantry staples", [ "salt" ] ]
    ])
  end

  it "renders every parsed ingredient name from a combined source ingredient row" do
    create(:ingredient, name: "salt", optional: true)
    create(:ingredient, name: "black pepper", optional: true)
    recipe = create(
      :recipe,
      title: "Eggs Over Easy",
      ingredients: [ "salt and ground black pepper to taste" ],
      ingredient_names: [ "salt", "black pepper" ],
      ingredient_parse_data: [
        {
          "parser" => {
            "name" => [ { "text" => "salt" }, { "text" => "black pepper" } ],
            "preparation" => { "text" => "ground" },
            "comment" => { "text" => "to taste" }
          }
        }
      ]
    )

    get recipe_path(recipe)

    document = Nokogiri::HTML(response.body)
    row = document.at_css(".recipe-ingredient-row")

    expect(row.css(".recipe-ingredient-link").map { |node| node.text.squish }).to eq([ "salt", "black pepper" ])
    expect(row.css(".recipe-ingredient-link").map { |node| JSON.parse(node["data-ingredient-match-names"]) }).to eq([
      [ "salt", "black pepper" ],
      [ "salt", "black pepper" ]
    ])
  end

  it "shows a recipe by trailing id when the friendly slug text is stale" do
    recipe = create(:recipe, title: "Quick Tomato Pasta")

    get "/recipes/stale-friendly-title-#{recipe.id}"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Quick Tomato Pasta")
  end

  def vector(first_value, second_value = 0.0)
    [ first_value, second_value ] + Array.new(382, 0.0)
  end

  def recipe_catalog_from(document)
    JSON.parse(document.at_css("script[data-recipe-catalog]").text)
  end

  def ingredient_basket_cookie(payload)
    "#{RecipesController::INGREDIENT_BASKET_COOKIE}=#{CGI.escape(payload.to_json)}"
  end

  def create_recipe_ingredient_rows
    Recipe.connection.exec_query(RecipeIngredientRecomputeQuery.call(recipe_ids: Recipe.ids), RecipeIngredientRecomputeQuery.name)
  end
end
