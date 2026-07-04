require "rails_helper"

RSpec.describe "Avo", type: :request do
  it "requires basic authentication" do
    get "/avo"

    expect(response).to have_http_status(:unauthorized)
  end

  it "uses the maintenance task credentials" do
    get "/avo/resources/ingredients", headers: basic_auth_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Ingredients")
  end

  it "serves the recipe admin resource" do
    create(:recipe)

    get "/avo/resources/recipes", headers: basic_auth_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Recipes")
  end

  def basic_auth_headers
    {
      "HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials("pennylunch", "pennylunch")
    }
  end
end
