require "csv"

module Recipes
  class ImportCopyQuery
    COPY_COLUMNS = %w[
      title
      cook_time
      prep_time
      ingredients
      ingredient_names
      ingredient_parse_data
      ratings
      cuisine
      category
      category_normalized
      author
      image
      total_time
      source_position
      created_at
      updated_at
    ].freeze
    COPY_SQL = "COPY recipes (#{COPY_COLUMNS.join(', ')}) FROM STDIN WITH (FORMAT csv)"
    LOCK_SQL = "LOCK TABLE recipes IN EXCLUSIVE MODE"

    def self.lock_table
      Recipe.connection.execute(LOCK_SQL)
    end

    def self.copy(rows)
      raw_connection = Recipe.connection.raw_connection
      raw_connection.copy_data(COPY_SQL) do
        rows.each { |row| raw_connection.put_copy_data(CSV.generate_line(row)) }
      end
    end
  end
end
