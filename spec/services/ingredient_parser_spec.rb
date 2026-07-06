require "rails_helper"

RSpec.describe IngredientParser do
  it "returns normalized names and parser details from the real Python parser" do
    result = described_class.call([
      [
        "1 cup flour",
        "2 eggs",
        "salt and ground black pepper to taste"
      ]
    ]).first

    expect(result.ingredient_names).to eq([ "flour", "eggs", "salt", "black pepper" ])
    expect(result.ingredient_parse_data.map { |entry| entry.fetch("input") }).to eq([
      "1 cup flour",
      "2 eggs",
      "salt and ground black pepper to taste"
    ])
    expect(result.ingredient_parse_data[0].dig("parser", "amount", 0, "quantity")).to eq("1")
    expect(result.ingredient_parse_data[0].dig("parser", "amount", 0, "unit")).to eq("cup")
    expect(result.ingredient_parse_data[1].dig("parser", "amount", 0, "quantity")).to eq("2")
    expect(result.ingredient_parse_data[2].dig("parser", "name").map { |name| name.fetch("text") }).to eq([ "salt", "black pepper" ])
    expect(result.ingredient_parse_data[2].dig("parser", "preparation", "text")).to eq("ground")
    expect(result.ingredient_parse_data[2].dig("parser", "comment", "text")).to eq("to taste")
  end

  it "normalizes blank and repeated parser names across ingredient lists" do
    results = described_class.call([
      [ "", "3 cloves garlic, minced", "garlic" ],
      [ "200g spaghetti", nil, "extra virgin olive oil" ]
    ])

    expect(results.map(&:ingredient_names)).to eq([
      [ "garlic" ],
      [ "spaghetti", "extra virgin olive oil" ]
    ])
    expect(results.first.ingredient_parse_data.map { |entry| entry.fetch("input") }).to eq([
      "3 cloves garlic, minced",
      "garlic"
    ])
    expect(results.first.ingredient_parse_data.first.dig("parser", "preparation", "text")).to eq("minced")
    expect(results.second.ingredient_parse_data.first.dig("parser", "amount", 0, "unit")).to eq("gram")
  end
end
