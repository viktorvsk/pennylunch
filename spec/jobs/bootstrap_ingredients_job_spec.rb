require "rails_helper"

RSpec.describe BootstrapIngredientsJob, type: :job do
  it "upserts ingredients from the manual alias catalog" do
    avocado = create(:ingredient, name: "avocado", aliases: [ "old avocado" ])
    retained = create(:ingredient, name: "turmeric", aliases: [ "turmeric" ])

    with_alias_catalog(<<~YAML) do |path|
      ingredients:
        avocado:
          aliases:
            - avocado
            - avocados
            - ripe avocado
        salt:
          optional: true
          aliases:
            - salt
            - kosher salt
    YAML

      stub_const("#{described_class}::CATALOG_PATH", path)
      described_class.perform_now

      expect(avocado.reload.aliases).to eq([ "avocado", "avocados", "ripe avocado" ])
      expect(Ingredient.find_by!(name: "salt")).to be_optional
      expect(Ingredient.find_by(id: retained.id)).to be_present
    end
  end

  it "uses normalized names, aliases, and boolean optional values in the real alias catalog" do
    ingredients = YAML.safe_load_file(described_class::CATALOG_PATH)["ingredients"]
    optional_values = ingredients.values.map { |attributes| attributes["optional"] || false }.uniq
    normalized_name = ->(name) { name.to_s.squish.downcase.presence }
    invalid_names = ingredients.keys.reject { |name| name == normalized_name.call(name) }
    invalid_aliases = ingredients.values.flat_map { |attributes| attributes["aliases"] }.reject { |name| name == normalized_name.call(name) }

    expect(invalid_names).to be_empty
    expect(invalid_aliases).to be_empty
    expect(optional_values).to match_array([ true, false ])
  end

  def with_alias_catalog(yaml)
    path = Rails.root.join("tmp/test-ingredient-aliases.yml")
    path.write(yaml)
    yield path
  ensure
    path.delete if path&.exist?
  end
end
