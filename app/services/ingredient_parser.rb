require "json"
require "open3"
require "set"
require "timeout"

class IngredientParser
  class Error < StandardError; end

  Result = Data.define(:ingredient_names, :ingredient_parse_data)

  SCRIPT = Rails.root.join("libexec", "parse_ingredients.py").to_s
  DEFAULT_TIMEOUT_SECONDS = 120
  STDERR_PREVIEW_LENGTH = 500

  class << self
    def call(ingredient_lists, timeout_seconds: SETTINGS.ingredient_parser_timeout_seconds)
      timeout_seconds = timeout_seconds.to_i.positive? ? timeout_seconds.to_i : DEFAULT_TIMEOUT_SECONDS
      normalized_lists = normalized_ingredient_lists(ingredient_lists)
      response = JSON.parse(parser_stdout(JSON.generate(ingredient_lists: normalized_lists), timeout_seconds))
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
      raise Error, "ingredient parser response ingredient_names must be an array" unless parsed_names.is_a?(Array)
      raise Error, "ingredient parser response ingredient_parse_data must be an array" unless parsed_data.is_a?(Array)
      raise Error, "ingredient parser returned #{parsed_names.size} name lists for #{expected_size} inputs" unless parsed_names.size == expected_size
      raise Error, "ingredient parser returned #{parsed_data.size} data lists for #{expected_size} inputs" unless parsed_data.size == expected_size
    end

    def normalized_ingredient_lists(ingredient_lists)
      Array(ingredient_lists).map do |lines|
        Array(lines).filter_map do |line|
          line.to_s.strip.presence
        end
      end
    end

    def normalized_names(names)
      seen = Set.new

      Array(names).filter_map do |name|
        normalized = name.to_s.squish.downcase
        next if normalized.blank? || seen.include?(normalized)

        seen << normalized
        normalized
      end
    end
  end
end
