require "rails_helper"

RSpec.describe RecipeIndexEntry do
  it "builds indexed recipe state from a parser result and ingredient lookup" do
    recipe = build_stubbed(:recipe)
    vector = Array.new(384, 0.1)
    parser_result = IngredientParser::Result.new(
      [ "lemon", "chicken breasts", "salt" ],
      [ { "input" => "1 lemon" } ]
    )
    allow(LocalEmbedding).to receive(:call).and_return(vector)

    entry = described_class.from(
      recipe:,
      parser_result:,
      ingredient_lookup: {
        "lemon" => "lemon",
        "chicken breasts" => "chicken breast"
      }
    )

    expect(entry.ingredient_names).to eq([ "lemon", "chicken breasts", "salt" ])
    expect(entry.ingredient_parse_data).to eq([ { "input" => "1 lemon" } ])
    expect(entry.ingredients_vector).to eq(vector)
    expect(LocalEmbedding).to have_received(:call).with("lemon\nchicken breast")
  end

  it "leaves vector empty when no ingredient names map to filterable catalog names" do
    recipe = build_stubbed(:recipe)
    parser_result = IngredientParser::Result.new([ "unknown sauce" ], [])
    allow(LocalEmbedding).to receive(:call)

    entry = described_class.from(
      recipe:,
      parser_result:,
      ingredient_lookup: {}
    )

    expect(entry.ingredients_vector).to be_nil
  end
end
