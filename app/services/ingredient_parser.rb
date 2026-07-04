require "open3"
require "timeout"

# Normalizes batches of raw recipe ingredient lines and sends them to the local
# Python ingredient parser.
#
# Returns `Array<IngredientParser::Result>`, one result per submitted ingredient
# list. Each result has `ingredient_names: Array<String>` and
# `ingredient_parse_data: Array<Hash>` aligned to the parser response.
#
# Raises `IngredientParser::Error` for invalid parser JSON, missing response
# keys, response-size mismatches, non-zero script exits, startup failures, and
# timeouts.
class IngredientParser
  class Error < StandardError; end

  Result = Data.define(:ingredient_names, :ingredient_parse_data)
  SCRIPT = Rails.root.join("libexec", "parse_ingredients.py").to_s
  STDERR_PREVIEW_LENGTH = 500

  class << self
    def call(ingredient_lists, timeout_seconds: SETTINGS.ingredient_parser_timeout_seconds)
      normalized_lists = normalized_ingredient_lists(ingredient_lists)
      response = JSON.parse(parser_stdout(JSON.generate(ingredient_lists: normalized_lists), timeout_seconds.to_i))
      parsed_names = response.fetch("ingredient_names")
      parsed_data = response.fetch("ingredient_parse_data")
      validate_response(parsed_names, parsed_data, normalized_lists.size)

      parsed_names.zip(parsed_data).map do |names, parse_data|
        Result.new(normalized_names(names), Array(parse_data))
      end
    rescue JSON::ParserError => error
      raise Error, "ingredient parser returned invalid JSON: #{error.message}"
    rescue KeyError => error
      raise Error, "ingredient parser response is missing #{error.key}"
    end

    private

    def parser_stdout(payload, timeout_seconds)
      stdout, stderr, status = Timeout.timeout(timeout_seconds) do
        Open3.capture3("python", SCRIPT, stdin_data: payload)
      end

      return stdout if status.success?

      raise Error, parser_failure_message(status, stderr)
    rescue Timeout::Error
      raise Error, "ingredient parser timed out after #{timeout_seconds} seconds"
    rescue SystemCallError => error
      raise Error, "ingredient parser could not be started: #{error.message}"
    end

    def parser_failure_message(status, stderr)
      details = stderr.to_s.strip[0, STDERR_PREVIEW_LENGTH]
      message = "ingredient parser failed with status #{status.exitstatus}"
      details.present? ? "#{message}: #{details}" : message
    end

    def validate_response(parsed_names, parsed_data, expected_size)
      raise Error, "ingredient parser returned #{parsed_names.size} name lists for #{expected_size} inputs" unless parsed_names.size == expected_size
      raise Error, "ingredient parser returned #{parsed_data.size} data lists for #{expected_size} inputs" unless parsed_data.size == expected_size
    end

    def normalized_ingredient_lists(ingredient_lists)
      Array(ingredient_lists).map do |lines|
        Array(lines).filter_map { it.to_s.strip.presence }
      end
    end

    def normalized_names(names)
      Array(names).filter_map { it.to_s.squish.downcase.presence }.uniq
    end
  end
end
