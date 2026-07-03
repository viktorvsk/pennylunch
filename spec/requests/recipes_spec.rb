require "rails_helper"

RSpec.describe "Recipes", type: :request do
  it "shows an empty index" do
    get recipes_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Nothing found")
    expect(response.body).to include("M8 16a5 5 0 0 1 8 0")
    expect(response.body).not_to include("Import recipes")
    expect(response.body).not_to include("<h1")
  end

  it "filters recipes and links to the show page" do
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
    expect(response.body).to include(recipe_path(recipe.slug))
    document = Nokogiri::HTML(response.body)
    expect(document.css("a[href='#{recipe_path(recipe.slug)}'][data-turbo-frame='_top']").size).to eq(2)
    expect(document.css("a[href='/recipes/pasta'][data-turbo-frame='_top']")).not_to be_empty
    expect(document.at_css("div[role='option'][data-value='air fryer main dish recipes'][data-label='Air Fryer Main Dish Recipes']").text).to eq("Air Fryer Main Dish Recipes")
    expect(response.body).to include("data-tooltip=\"Rating: 4.95 out of 5\"")
    expect(response.body).to include("data-tooltip=\"Prep: 10 min, cook: 20 min\"")
    expect(response.body).to include("href=\"/recipes/pasta\"")
    expect(response.body).to include("tomato, pasta, garlic")
    ingredient_summary = document.at_css("[data-recipe-ingredients]")
    expect(JSON.parse(ingredient_summary["data-ingredient-names"])).to eq([ "tomato", "pasta", "garlic" ])
    expect(response.body).to include("M20 21a8 8 0 0 0-16 0")
    expect(response.body).to include("M12 6v6l4 2")
    expect(response.body).to include("href=\"/\"")
    expect(response.body).to include("role=\"switch\"")
    expect(response.body).to include("role=\"combobox\"")
    expect(response.body).to include("class=\"dropdown-menu")
    expect(response.body).to include("data-tooltip=\"Category: Pasta\"")
    expect(response.body).to include("class=\"recipe-toolbar sticky top-0")
    expect(response.body).to include("recipe-toolbar-loading")
    expect(response.body).to include("turbo.min")
    expect(response.body).to include("data-ingredients-filter-hidden=\"true\"")
    expect(response.body).to include("id=\"recipe-results-frame\"")
    expect(response.body).to include("id=\"recipe-ingredients-fab\"")
    expect(response.body).to include("data-turbo-permanent")
    expect(response.body).to include("data-ingredients-fab")
    expect(response.body).to include("Ingredients at home")
    expect(response.body).to include("Pick matching ingredients. Enable to include them in filters.")
    expect(response.body).to include("data-ingredient-options")
    expect(response.body).to include("data-ingredients-filter-input")
    expect(response.body).to include("data-ingredients-selected-list")
    expect(response.body).to include("tomato")
    expect(response.body).not_to include("data-ingredients-filter-textarea")
    expect(response.body).to include("<h1 class=\"text-2xl font-semibold tracking-normal\">Pasta</h1>")
    expect(response.body).to include("aria-label=\"Maintenance\"")
    expect(response.body).not_to include("Show recipes")
    expect(response.body).not_to include(">Clear<")
    expect(response.body).not_to include(">Maintenance<")
    expect(response.body).not_to include("overflow-x-auto")
  end

  it "renders infinite scroll instead of totals and pagination links" do
    create_list(:recipe, Recipes::Search::PER_PAGE + 1)

    get recipes_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("id=\"recipe-results\"")
    expect(response.body).to include("data-infinite-scroll-sentinel")
    expect(response.body).to include("data-next-url=\"/recipes?page=2\"")
    expect(response.body).to include("infinite-scroll-spinner")
    expect(response.body).not_to include("#{Recipes::Search::PER_PAGE + 1} recipes")
    expect(response.body).not_to include(">Next<")
  end

  it "renders only the results frame for Turbo frame filter requests" do
    create(:recipe, title: "Onion Soup")

    get recipes_path, params: { q: "onion" }, headers: { "Turbo-Frame" => "recipe-results-frame" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("id=\"recipe-results-frame\"")
    expect(response.body).to include("Onion Soup")
    expect(response.body).not_to include("recipe-toolbar")
    expect(response.body).not_to include("recipe-ingredients-fab")
    expect(response.body).not_to include("data-ingredient-options")
  end

  it "suggests a category from the empty state when filters find no recipes" do
    create(:recipe, category: "Pasta", category_normalized: "pasta")

    get recipes_path, params: { q: "not-a-real-title" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Nothing found")
    expect(response.body).to include("href=\"/recipes/pasta\"")
    expect(response.body).not_to include("Import recipes")
  end

  it "redirects query category filters to category slug paths" do
    create(:recipe, category: "Pasta", category_normalized: "pasta")

    get recipes_path, params: { q: "tomato", category: "pasta", sort: "rating_desc" }

    expect(response).to redirect_to("/recipes/pasta?q=tomato&sort=rating_desc")
    expect(response).to have_http_status(:see_other)
  end

  it "filters recipes by available ingredients through vector search" do
    pasta = create(:recipe, title: "Pasta and Garlic", ingredients_vector: vector(1.0))
    create(:recipe, title: "Apple Cake", ingredients_vector: vector(-1.0))
    allow(IngredientParser).to receive(:call).and_return([
      IngredientParser::Result.new([ "pasta", "garlic", "olive oil" ], [])
    ])
    allow(LocalEmbedding).to receive(:call).and_return(vector(1.0))

    get recipes_path, params: { ingredients: "pasta garlic olive oil", sort: "rating_desc" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Pasta and Garlic")
    expect(response.body).not_to include("Apple Cake")
    expect(response.body).to include(recipe_path(pasta.slug))
    expect(response.body).to include("value=\"pasta garlic olive oil\"")
    expect(response.body).to include("data-current-enabled=\"true\"")
  end

  it "shows a recipe and its ingredients" do
    recipe = create(
      :recipe,
      title: "Quick Tomato Pasta",
      prep_time: 0,
      cook_time: 0,
      ratings: 4.59,
      category: "Pasta",
      ingredients: [ "2 tomatoes", "200g pasta" ],
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
    similar_titles = 3.times.map { |index| create(:recipe, title: "Similar Pasta #{index}", category: "Pasta").title }
    create(:recipe, title: "Other Dinner", category: "Dinner")

    get recipe_path(recipe.slug)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Quick Tomato Pasta")
    expect(response.body).to include("https://images.media-allrecipes.com/userphotos/8263243.jpg")
    expect(response.body).to include("data-tooltip=\"Rating: 4.59 out of 5\"")
    document = Nokogiri::HTML(response.body)
    expect(document.css("span").map { |node| node.text.squish }).not_to include("0 min")
    expect(response.body).to include("href=\"/\"")
    expect(response.body).to include("href=\"/recipes/pasta\"")
    expect(response.body).to include("class=\"recipe-toolbar sticky top-0")
    expect(response.body).to include("aria-label=\"Maintenance\"")
    expect(response.body).to include("recipe-show-card")
    expect(response.body).to include("Ingredients")
    expect(response.body).to include("2")
    expect(response.body).to include("200")
    expect(response.body).to include("g")
    expect(response.body).to include("peeled")
    ingredient_links = document.css(".recipe-ingredient-link").map { |node| [ node.text.squish, node["href"], node["target"], node["rel"] ] }
    expect(ingredient_links).to include([ "tomatoes", "https://en.wikipedia.org/wiki/tomatoes", "_blank", "noopener" ])
    expect(document.css(".recipe-ingredient-link[data-ingredient-name]").map { |node| node["data-ingredient-name"] }).to include("tomatoes", "pasta")
    expect(response.body).to include("Similar recipes")
    similar_titles.each { |title| expect(response.body).to include(title) }
    expect(response.body).not_to include("Other Dinner")
    expect(response.body).not_to include("aria-label=\"Breadcrumb\"")
    expect(response.body).to include("role=\"switch\"")
    expect(response.body).to include("role=\"combobox\"")
    expect(response.body).to include("id=\"recipe-ingredients-fab\"")
    expect(response.body).not_to include("rounded-md bg-muted")
    expect(response.body.index("<h1")).to be < response.body.index("<img")
  end

  def vector(first_value)
    [ first_value ] + Array.new(383, 0.0)
  end
end
