# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Brand assets" do
  it "keeps the legacy SVG icon URL aligned with the canonical pen mark" do
    expect(Rails.root.join("public/icon.svg").read).to eq(Rails.root.join("public/pen.svg").read)
  end

  it "uses the color pen mark as the basket empty-state background" do
    stylesheet = Rails.root.join("app/assets/stylesheets/recipe_ingredients_fab.css").read

    expect(Rails.root.join("public/icon-512x512.png")).to exist
    expect(stylesheet).to include('url("/icon-512x512.png")')
    expect(stylesheet).to include(".recipe-ingredients-empty-state::before")
  end

  it "uses the color pen mark as the recipe image loading placeholder" do
    stylesheet = Rails.root.join("app/assets/stylesheets/recipe_cards.css").read

    expect(Rails.root.join("public/icon-512x512.png")).to exist
    expect(stylesheet).to include('url("/icon-512x512.png")')
    expect(stylesheet).to include(".recipe-card-image::before")
    expect(stylesheet).to include(".recipe-card-image::after")
    expect(stylesheet).to include("@keyframes recipe-card-image-sweep")
    expect(stylesheet).to include("animation: recipe-card-image-sweep")
    expect(stylesheet).to include("@media (prefers-reduced-motion: reduce)")
  end
end
