require "rails_helper"

RSpec.describe Avo::Resources::Recipe do
  it "exposes recipe fields and destructive actions for Avo management" do
    resource = described_class.new(view: :index)
    resource.detect_fields

    expect(resource.title).to eq(:title)
    expect(resource.get_field_definitions.map(&:id)).to eq([ :id, :title, :category, :author, :ratings, :total_time, :ingredient_names ])
    expect(resource.get_field_definitions.map(&:type)).to eq([ "id", "text", "text", "text", "number", "number", "tags" ])
    expect(resource.get_actions.map { |action| action.fetch(:class) }).to eq([
      Avo::Actions::ImportRecipes,
      Avo::Actions::IndexSelectedRecipes,
      Avo::Actions::SetRecipeSearchStrategy,
      Avo::Actions::DeleteSelectedRecipes
    ])
  end
end
