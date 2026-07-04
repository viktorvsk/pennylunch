require "rails_helper"

RSpec.describe "recipe routes", type: :routing do
  it "routes recipe slugs ending in an id to the recipe show action" do
    expect(get: "/recipes/Tomato-Pasta-Pasta-Maker-23-minutes-42").to route_to(
      controller: "recipes",
      action: "show",
      id: "Tomato-Pasta-Pasta-Maker-23-minutes-42"
    )
  end

  it "routes slugs without a trailing id to the category index" do
    expect(get: "/recipes/pasta").to route_to(
      controller: "recipes",
      action: "index",
      category_slug: "pasta"
    )
  end
end
