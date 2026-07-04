require "rails_helper"

RSpec.describe Avo::Resources::Ingredient do
  it "exposes ingredient fields for Avo management" do
    resource = described_class.new(view: :index)
    resource.detect_fields

    expect(resource.title).to eq(:name)
    expect(resource.get_field_definitions.map(&:id)).to eq([ :id, :name, :optional, :aliases ])
    expect(resource.get_field_definitions.map(&:type)).to eq([ "id", "text", "boolean", "tags" ])
    expect(resource.get_actions.map { |action| action.fetch(:class) }).to eq([
      Avo::Actions::DeleteSelectedIngredients
    ])
  end
end
