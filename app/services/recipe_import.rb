require "csv"
require "open-uri"
require "stringio"
require "zlib"

class RecipeImport
  DEFAULT_URL = "https://pennylane-interviewing-assets-20220328.s3.eu-west-1.amazonaws.com/recipes-en.json.gz"
  DEFAULT_DOWNLOADER = ->(source_url) { URI.open(source_url, "rb", &:read) }
  SOURCE_FIELDS = %w[author category cook_time cuisine image ingredients prep_time ratings title].freeze

  class Error < StandardError; end
  class NonEmptyDestinationError < Error; end
  class InvalidSourceError < Error; end
  class DuplicateSourceIdentityError < Error; end

  COPY_COLUMNS = %w[
    title cook_time prep_time ingredients ingredient_names ingredient_parse_data
    ratings cuisine category category_normalized author image total_time source_position created_at updated_at
  ].freeze
  COPY_SQL = "COPY recipes (#{COPY_COLUMNS.join(', ')}) FROM STDIN WITH (FORMAT csv)"
  LOCK_SQL = "LOCK TABLE recipes IN EXCLUSIVE MODE"

  class << self
    def call(url:, downloader: DEFAULT_DOWNLOADER)
      raise NonEmptyDestinationError, "recipes table must be empty before MVP import" if Recipe.exists?

      records = records_from_payload(downloader.call(url))
      validate_records(records)

      Recipe.transaction do
        Recipe.connection.execute(LOCK_SQL)
        raise NonEmptyDestinationError, "recipes table must be empty before MVP import" if Recipe.exists?

        copy_records(records)
      end

      records.size
    end

    private

    def records_from_payload(payload)
      Zlib::GzipReader.wrap(StringIO.new(payload)) { |gzip| JSON.parse(gzip.read) }
    end

    def validate_records(records)
      raise InvalidSourceError, "source payload must be a JSON array" unless records.is_a?(Array)

      identities = records.map.with_index do |record, index|
        validate_record(record, index)
        [
          record.fetch("title").to_s.strip.downcase,
          record.fetch("category").to_s.strip.downcase,
          record.fetch("author").to_s.strip.downcase
        ]
      end

      raise DuplicateSourceIdentityError, "source contains duplicate title/category/author identities" unless identities.uniq.size == identities.size
    end

    def validate_record(record, index)
      raise InvalidSourceError, "record #{index} must be an object" unless record.is_a?(Hash)
      raise InvalidSourceError, "record #{index} has unexpected fields" unless record.keys.sort == SOURCE_FIELDS
      raise InvalidSourceError, "record #{index} ingredients must be an array" unless record.fetch("ingredients").is_a?(Array)
    end

    def copy_records(records)
      now = Time.current.utc.iso8601(6)
      raw_connection = Recipe.connection.raw_connection

      raw_connection.copy_data(COPY_SQL) do
        records.each_with_index do |record, index|
          total_time = record.fetch("prep_time").to_i + record.fetch("cook_time").to_i
          row = [
            record.fetch("title"),
            record.fetch("cook_time"),
            record.fetch("prep_time"),
            JSON.generate(record.fetch("ingredients")),
            JSON.generate([]),
            JSON.generate([]),
            record.fetch("ratings"),
            record.fetch("cuisine"),
            record.fetch("category"),
            Recipe.normalize_category(record.fetch("category")),
            record.fetch("author"),
            record.fetch("image"),
            total_time,
            index,
            now,
            now
          ]
          raw_connection.put_copy_data(CSV.generate_line(row))
        end
      end
    end
  end
end
