require "rails_helper"
require "tmpdir"

RSpec.describe IngredientParser do
  it "shells out to the parser command and normalizes names with structured parser data" do
    with_parser_script(<<~RUBY) do |script|
      require "json"

      payload = JSON.parse($stdin.read)
      parsed_names = payload.fetch("ingredient_lists").map do |lines|
        lines.flat_map { |line| line == "1 cup flour" ? ["Flour", "flour"] : ["Egg"] }
      end
      parsed_data = payload.fetch("ingredient_lists").map do |lines|
        lines.map do |line|
          {
            "input" => line,
            "parser" => {
              "sentence" => line,
              "amount" => [{ "quantity" => "1", "unit" => "cup" }]
            }
          }
        end
      end
      puts JSON.generate("ingredient_names" => parsed_names, "ingredient_parse_data" => parsed_data)
    RUBY
      result = described_class.call(
        [
          [ "1 cup flour", "1 egg" ]
        ],
        python: RbConfig.ruby,
        script:,
        timeout_seconds: 5
      )

      expect(result).to eq([
        IngredientParser::Result.new(
          [ "flour", "egg" ],
          [
            {
              "input" => "1 cup flour",
              "parser" => {
                "sentence" => "1 cup flour",
                "amount" => [ { "quantity" => "1", "unit" => "cup" } ]
              }
            },
            {
              "input" => "1 egg",
              "parser" => {
                "sentence" => "1 egg",
                "amount" => [ { "quantity" => "1", "unit" => "cup" } ]
              }
            }
          ]
        )
      ])
    end
  end

  it "raises a clear error when the parser returns invalid JSON" do
    with_parser_script("puts 'not json'\n") do |script|
      expect do
        described_class.call([ [ "1 cup flour" ] ], python: RbConfig.ruby, script:, timeout_seconds: 5)
      end.to raise_error(IngredientParser::Error, /invalid JSON/)
    end
  end

  def with_parser_script(source)
    Dir.mktmpdir("ingredient-parser") do |dir|
      script = File.join(dir, "parser.rb")
      File.write(script, source)
      yield script
    end
  end
end
