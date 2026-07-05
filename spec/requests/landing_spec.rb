require "rails_helper"

RSpec.describe "Landing page", type: :request do
  it "serves the startup landing page at root" do
    get root_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Dinner from your fridge")
    expect(response.body).to include("Smart-match recipes")
    expect(response.body).to include("Find tonight's dinner")
    expect(response.body).to include("href=\"/recipes\"")
    expect(response.body).to include("src=\"/pen.svg\"")
    expect(response.body).to include("content=\"/icon-512x512.png\"")
    expect(response.body).to include("PennyLunch")
    expect(response.body).not_to include("id=\"recipe-ingredients-fab\"")
    expect(response.body).not_to include("data-controller=\"recipe-ui")
    expect(response.body).not_to include("—")
  end

  it "keeps the recipe application available at /recipes" do
    get recipes_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("id=\"recipe-results-frame\"")
    expect(response.body).to include("Search recipes")
  end
end
