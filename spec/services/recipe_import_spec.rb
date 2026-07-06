require "rails_helper"
require "zlib"

RSpec.describe RecipeImport do
  subject(:import) { described_class.call(url:) }

  let(:url) { "https://example.test/recipes.json.gz" }
  let(:source_records) do
    [
      {
        "title" => "Golden Sweet Cornbread",
        "cook_time" => 25,
        "prep_time" => 10,
        "ingredients" => [ "1 cup flour", "1 egg", "1 cup milk" ],
        "ratings" => 4.74,
        "cuisine" => "",
        "category" => "Cornbread",
        "author" => "bluegirl",
        "image" => "https://example.com/cornbread.jpg"
      },
      {
        "title" => "Tomato Pasta",
        "cook_time" => 15,
        "prep_time" => 8,
        "ingredients" => [ "2 tomatoes", "200g pasta", "basil" ],
        "ratings" => 4.91,
        "cuisine" => "",
        "category" => "",
        "author" => "Pasta Maker",
        "image" => "https://example.com/pasta.jpg"
      }
    ]
  end

  before do
    allow(URI).to receive(:open).with(url, "rb") { gzipped(source_records) }
  end

  it "imports recipes and leaves derived indexing fields empty" do
    expect(import).to eq(2)
    expect(Recipe.order(:source_position).map { |recipe| source_hash(recipe) }).to eq(source_records)
    expect(Recipe.order(:source_position).pluck(:ingredient_names, :ingredient_parse_data, :ingredients_vector)).to eq([
      [ [], [], nil ],
      [ [], [], nil ]
    ])
  end

  it "fails before writing when recipes already exist" do
    create(:recipe)

    expect { import }.to raise_error(RecipeImport::NonEmptyDestinationError)
    expect(Recipe.count).to eq(1)
  end

  it "rejects duplicate source identities" do
    source_records << source_records.first.merge("cook_time" => 30)

    expect { import }.to raise_error(RecipeImport::DuplicateSourceIdentityError)
    expect(Recipe.count).to eq(0)
  end

  it "rejects a source payload that is not a recipe array" do
    allow(URI).to receive(:open).with(url, "rb") { gzipped("not recipes") }

    expect { import }.to raise_error(RecipeImport::InvalidSourceError, /JSON array/)
    expect(Recipe.count).to eq(0)
  end

  it "rejects recipe records with invalid source shape" do
    source_records.first["ingredients"] = "1 cup flour"

    expect { import }.to raise_error(RecipeImport::InvalidSourceError, /ingredients must be an array/)
    expect(Recipe.count).to eq(0)
  end

  def gzipped(records)
    io = StringIO.new
    Zlib::GzipWriter.wrap(io) { |gzip| gzip.write(JSON.generate(records)) }
    io.string
  end

  def source_hash(recipe)
    {
      "title" => recipe.title,
      "cook_time" => recipe.cook_time,
      "prep_time" => recipe.prep_time,
      "ingredients" => recipe.ingredients,
      "ratings" => recipe.ratings.to_f,
      "cuisine" => recipe.cuisine,
      "category" => recipe.category,
      "author" => recipe.author,
      "image" => recipe.image
    }
  end
end
