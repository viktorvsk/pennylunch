require "rails_helper"
require "zlib"

RSpec.describe RecipeImport do
  subject(:import) { described_class.call(url: "https://example.test/recipes.json.gz", downloader:) }

  let(:downloader) { ->(_url) { gzipped(source_records) } }
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

  it "imports recipes and stores source-shaped JSON in denormalized columns" do
    create(:ingredient, name: "tomato", aliases: [ "tomatoes" ], optional: true)
    create(:ingredient, name: "flour")
    create(:ingredient, name: "egg")
    create(:ingredient, name: "milk")
    create(:ingredient, name: "pasta")
    create(:ingredient, name: "basil")

    expect(IngredientParser).not_to receive(:call)
    expect(import).to eq(2)
    expect(Recipe.order(:source_position).map { |recipe| source_hash(recipe) }).to eq(source_records)
    expect(Recipe.order(:source_position).pluck(:ingredient_names, :ingredient_parse_data)).to eq([
      [ [], [] ],
      [ [], [] ]
    ])
    expect(RecipeIngredient.count).to eq(0)
  end

  it "leaves derived ingredient data empty for recipe indexing" do
    import

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

  it "requires an explicit source URL" do
    expect { described_class.call(downloader:) }.to raise_error(ArgumentError, /missing keyword: :url/)
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
