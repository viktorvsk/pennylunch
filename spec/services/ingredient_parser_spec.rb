require "rails_helper"
require "tmpdir"

RSpec.describe IngredientParser do
  it "shells out to the parser command and normalizes names with structured parser data" do
    with_parser_script(<<~PYTHON) do |script|
      import json
      import sys

      payload = json.loads(sys.stdin.read())
      parsed_names = [
          [
              name
              for line in lines
              for name in (["Flour", "flour"] if line == "1 cup flour" else ["Egg"])
          ]
          for lines in payload["ingredient_lists"]
      ]
      parsed_data = [
          [
              {
                  "input": line,
                  "parser": {
                      "sentence": line,
                      "amount": [{"quantity": "1", "unit": "cup"}],
                  },
              }
              for line in lines
          ]
          for lines in payload["ingredient_lists"]
      ]
      print(json.dumps({"ingredient_names": parsed_names, "ingredient_parse_data": parsed_data}))
    PYTHON
      stub_const("IngredientParser::SCRIPT", script)

      result = described_class.call(
        [
          [ "1 cup flour", "1 egg" ]
        ],
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
    with_parser_script("print('not json')\n") do |script|
      stub_const("IngredientParser::SCRIPT", script)

      expect do
        described_class.call([ [ "1 cup flour" ] ], timeout_seconds: 5)
      end.to raise_error(IngredientParser::Error, /invalid JSON/)
    end
  end

  def with_parser_script(source)
    Dir.mktmpdir("ingredient-parser") do |dir|
      script = File.join(dir, "parser.py")
      File.write(script, source)
      yield script
    end
  end
end
