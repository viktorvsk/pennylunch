require "rails_helper"

RSpec.describe RecipeIndexUpdateQuery do
  it "bulk updates indexed recipe fields for the target rows" do
    first = create(:recipe, ingredient_names: [ "old lemon" ], ingredient_parse_data: [], ingredients_vector: nil)
    second = create(:recipe, ingredient_names: [ "old pasta" ], ingredient_parse_data: [], ingredients_vector: nil)
    untouched = create(:recipe, ingredient_names: [ "apple" ], ingredients_vector: vector(0.9))
    first_vector = vector(0.1)
    second_vector = vector(0.2)
    entries = [
      entry_for(
        first,
        ingredient_names: [ "lemon" ],
        ingredient_parse_data: [ { "input" => "1 lemon" } ],
        ingredients_vector: first_vector
      ),
      entry_for(
        second,
        ingredient_names: [ "pasta", "garlic" ],
        ingredient_parse_data: [ { "input" => "200g pasta" } ],
        ingredients_vector: second_vector
      )
    ]
    query = described_class.call(entries:)

    expect(query).to start_with("UPDATE \"recipes\"")
    expect(first.reload.ingredient_names).to eq([ "old lemon" ])
    expect(second.reload.ingredient_names).to eq([ "old pasta" ])

    update_statements = recorded_sql do
      Recipe.connection.execute(query)
    end.grep(/\AUPDATE "recipes"/)

    expect(first.reload.ingredient_names).to eq([ "lemon" ])
    expect(first.ingredient_parse_data).to eq([ { "input" => "1 lemon" } ])
    expect(first.ingredients_vector).to eq(first_vector)
    expect(second.reload.ingredient_names).to eq([ "pasta", "garlic" ])
    expect(second.ingredient_parse_data).to eq([ { "input" => "200g pasta" } ])
    expect(second.ingredients_vector).to eq(second_vector)
    expect(untouched.reload.ingredient_names).to eq([ "apple" ])
    expect(untouched.ingredients_vector).to eq(vector(0.9))
    expect(update_statements.size).to eq(1)
  end

  def vector(first_value)
    [ first_value ] + Array.new(383, 0.0)
  end

  def entry_for(recipe, ingredient_names:, ingredient_parse_data:, ingredients_vector:)
    RecipeIndexEntry.new(recipe:, ingredient_names:, ingredient_parse_data:, ingredients_vector:)
  end

  def recorded_sql
    statements = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |_name, _started, _finished, _id, payload|
      statements << payload.fetch(:sql) unless payload[:cached] || payload[:name] == "SCHEMA"
    end

    yield
    statements
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end
end
