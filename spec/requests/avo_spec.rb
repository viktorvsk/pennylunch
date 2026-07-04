require "rails_helper"

RSpec.describe "Avo", type: :request do
  it "requires basic authentication" do
    get "/avo"

    expect(response).to have_http_status(:unauthorized)
  end

  it "uses the Avo credentials" do
    get "/avo/resources/ingredients", headers: basic_auth_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Ingredients")
  end

  it "opens ingredient actions for current-page selections" do
    ingredient = create(:ingredient, name: "salt")

    get "/avo/resources/ingredients/actions",
      params: {
        action_id: Avo::Actions::DeleteSelectedIngredients.to_param,
        resource_view: "index",
        fields: { avo_resource_ids: ingredient.to_param }
      },
      headers: basic_auth_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Delete the selected ingredients?")
  end

  it "opens ingredient catalog bootstrap actions" do
    get "/avo/resources/ingredients/actions",
      params: {
        action_id: Avo::Actions::BootstrapIngredients.to_param,
        resource_view: "index"
      },
      headers: basic_auth_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Bootstrap ingredients from alias catalog?")
  end

  it "serves the recipe admin resource" do
    create(:recipe)

    get "/avo/resources/recipes", headers: basic_auth_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Recipes")
  end

  it "opens recipe actions for current-page selections submitted with public recipe params" do
    recipe = create(:recipe, title: "Quick Tomato Pasta")

    get "/avo/resources/recipes/actions",
      params: {
        action_id: Avo::Actions::DeleteSelectedRecipes.to_param,
        resource_view: "index",
        fields: { avo_resource_ids: recipe.to_param }
      },
      headers: basic_auth_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Delete the selected recipes?")
  end

  it "opens standalone recipe import actions" do
    get "/avo/resources/recipes/actions",
      params: {
        action_id: Avo::Actions::ImportRecipes.to_param,
        resource_view: "index"
      },
      headers: basic_auth_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Import recipes from the source URL?")
  end

  def basic_auth_headers
    {
      "HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials("pennylunch", "pennylunch")
    }
  end
end
