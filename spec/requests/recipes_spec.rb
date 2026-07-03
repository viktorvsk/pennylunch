require "rails_helper"

RSpec.describe "Recipes", type: :request do
  it "shows an empty index" do
    get recipes_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Import recipes")
  end

  it "filters recipes and links to the show page" do
    recipe = create(:recipe, title: "Quick Tomato Pasta", category: "Pasta", category_normalized: "pasta", ratings: 4.95)
    create(:recipe, title: "Slow Roast Chicken", category: "Dinner", category_normalized: "dinner")

    get recipes_path, params: { q: "tomato", category: "pasta", popular: "1", sort: "rating_desc" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Quick Tomato Pasta")
    expect(response.body).not_to include("Slow Roast Chicken")
    expect(response.body).to include(recipe_path(recipe.slug))
    expect(response.body).to include("title=\"4.95 out of 5\"")
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
      image: "https://imagesvc.meredithcorp.io/v3/mm/image?url=https%3A%2F%2Fimages.media-allrecipes.com%2Fuserphotos%2F8263243.jpg"
    )

    get recipe_path(recipe.slug)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Quick Tomato Pasta")
    expect(response.body).to include("2 tomatoes")
    expect(response.body).to include("200g pasta")
    expect(response.body).to include("https://images.media-allrecipes.com/userphotos/8263243.jpg")
    expect(response.body).to include("title=\"4.59 out of 5\"")
    expect(response.body).not_to include("0 min")
    expect(response.body).to include("href=\"/\"")
    expect(response.body).to include("href=\"/recipes?category=pasta\"")
  end

  def vector(first_value)
    [ first_value ] + Array.new(383, 0.0)
  end
end
