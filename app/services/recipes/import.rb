require "csv"
require "open-uri"
require "stringio"
require "zlib"

module Recipes
  class Import
    Result = Data.define(:imported_count)
    CopyRow = Data.define(:record, :parser_result, :index, :timestamp)
    DEFAULT_DOWNLOADER = ->(source_url) { URI.open(source_url, "rb", &:read) }

    class Error < StandardError; end
    class NonEmptyDestinationError < Error; end
    class InvalidSourceError < Error; end
    class DuplicateSourceIdentityError < Error; end
    PARSER_BATCH_SIZE = 256

    def self.call(url: Rails.application.config.penny_lunch.recipes_import_url, downloader: DEFAULT_DOWNLOADER, ingredient_parser: IngredientParser)
      new(url:, downloader:, ingredient_parser:).call
    end

    def initialize(url:, downloader:, ingredient_parser:)
      @url = url
      @downloader = downloader
      @ingredient_parser = ingredient_parser
    end

    def call
      raise NonEmptyDestinationError, "recipes table must be empty before MVP import" if Recipe.exists?

      records = records_from_payload(downloader.call(url))
      validate_records(records)
      parser_results = parse_ingredients(records)
      raise Error, "ingredient parser returned #{parser_results.size} lists for #{records.size} source records" unless parser_results.size == records.size

      Recipe.transaction do
        Recipe.connection.execute("LOCK TABLE recipes IN EXCLUSIVE MODE")
        raise NonEmptyDestinationError, "recipes table must be empty before MVP import" if Recipe.exists?

        copy_records(records, parser_results)
      end

      Result.new(imported_count: records.size)
    end

    private

    attr_reader :url, :downloader, :ingredient_parser

    def records_from_payload(payload)
      gzip = Zlib::GzipReader.new(StringIO.new(payload))
      JSON.parse(gzip.read)
    ensure
      gzip&.close
    end

    def validate_records(records)
      raise InvalidSourceError, "source payload must be a JSON array" unless records.is_a?(Array)

      source_keys = records.map.with_index do |record, index|
        validate_record(record, index)
        Recipe.source_key_for(title: record.fetch("title"), category: record.fetch("category"), author: record.fetch("author"))
      end

      duplicates = source_keys.tally.select { |_key, count| count > 1 }
      raise DuplicateSourceIdentityError, "source contains duplicate title/category/author identities" if duplicates.any?
    end

    def validate_record(record, index)
      raise InvalidSourceError, "record #{index} must be an object" unless record.is_a?(Hash)
      raise InvalidSourceError, "record #{index} has unexpected fields" unless record.keys.sort == Recipe::SOURCE_FIELDS.sort
      raise InvalidSourceError, "record #{index} ingredients must be an array" unless record.fetch("ingredients").is_a?(Array)
    end

    def parse_ingredients(records)
      records.each_slice(PARSER_BATCH_SIZE).flat_map do |records_slice|
        ingredient_parser.call(records_slice.map { |record| record.fetch("ingredients") })
      end
    end

    def copy_records(records, parser_results)
      now = Time.current.utc.iso8601(6)
      raw_connection = Recipe.connection.raw_connection
      raw_connection.copy_data(copy_sql) do
        records.each_with_index do |record, index|
          raw_connection.put_copy_data(CSV.generate_line(copy_row(CopyRow.new(record, parser_results.fetch(index), index, now))))
        end
      end
    end

    def copy_sql
      <<~SQL.squish
        COPY recipes (
          title, cook_time, prep_time, ingredients, ingredient_names, ingredient_parse_data, ratings, cuisine, category, category_normalized,
          author, image, total_time, source_key, source_position, slug, created_at, updated_at
        ) FROM STDIN WITH (FORMAT csv)
      SQL
    end

    def copy_row(row)
      record = row.record
      total_time = record.fetch("prep_time").to_i + record.fetch("cook_time").to_i
      [
        record.fetch("title"),
        record.fetch("cook_time"),
        record.fetch("prep_time"),
        JSON.generate(record.fetch("ingredients")),
        postgres_text_array(row.parser_result.ingredient_names),
        JSON.generate(row.parser_result.ingredient_parse_data),
        record.fetch("ratings"),
        record.fetch("cuisine"),
        record.fetch("category"),
        Recipe.normalize_category(record.fetch("category")),
        record.fetch("author"),
        record.fetch("image"),
        total_time,
        Recipe.source_key_for(title: record.fetch("title"), category: record.fetch("category"), author: record.fetch("author")),
        row.index,
        Recipe.slug_for(title: record.fetch("title"), category: record.fetch("category"), author: record.fetch("author"), total_time:),
        row.timestamp,
        row.timestamp
      ]
    end

    def postgres_text_array(values)
      "{#{Array(values).map { |value| %("#{postgres_text_array_value(value)}") }.join(",")}}"
    end

    def postgres_text_array_value(value)
      value.to_s.gsub(/[\\"]/) { |character| "\\#{character}" }
    end
  end
end
