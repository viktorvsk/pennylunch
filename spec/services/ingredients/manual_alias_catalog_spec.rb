require "rails_helper"

RSpec.describe Ingredients::ManualAliasCatalog do
  it "loads canonical names, explicit aliases, and optional flags from YAML" do
    path = Rails.root.join("tmp/test-ingredient-aliases.yml")
    path.write(<<~YAML)
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

    entries = described_class.load(path:)

    expect(entries.map(&:name)).to eq([ "avocado", "salt" ])
    expect(entries.first.aliases).to eq([ "avocado", "avocados", "ripe avocado" ])
    expect(entries.last.optional).to be(true)
  ensure
    path.delete if path.exist?
  end

  it "rejects canonical names with commas" do
    path = Rails.root.join("tmp/test-ingredient-aliases.yml")
    path.write(<<~YAML)
      ingredients:
        "wheat, rye, and flax hot cereal mix":
          aliases:
            - wheat, rye, and flax hot cereal mix
    YAML

    expect { described_class.load(path:) }.to raise_error(described_class::Error, /must be canonical/)
  ensure
    path.delete if path.exist?
  end

  it "rejects aliases that resolve to multiple canonical names" do
    path = Rails.root.join("tmp/test-ingredient-aliases.yml")
    path.write(<<~YAML)
      ingredients:
        avocado:
          aliases:
            - avocado
            - avocados
        guacamole:
          aliases:
            - guacamole
            - avocado
    YAML

    expect { described_class.load(path:) }.to raise_error(described_class::Error, /multiple ingredients/)
  ensure
    path.delete if path.exist?
  end

  it "allows canonical names that are grouping labels rather than raw aliases" do
    path = Rails.root.join("tmp/test-ingredient-aliases.yml")
    path.write(<<~YAML)
      ingredients:
        cereal mix:
          aliases:
            - wheat, rye, and flax hot cereal mix
    YAML

    entry = described_class.load(path:).sole

    expect(entry.name).to eq("cereal mix")
    expect(entry.aliases).to eq([ "wheat, rye, and flax hot cereal mix" ])
  ensure
    path.delete if path.exist?
  end
end
