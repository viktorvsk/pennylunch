class RecipeIndexUpdateQuery
  class << self
    def call(entries:)
      entries = Array(entries)
      return if entries.empty?

      <<~SQL.squish
        UPDATE #{connection.quote_table_name(Recipe.table_name)}
        SET #{update_assignments(entries)}
        WHERE #{connection.quote_table_name(Recipe.table_name)}.#{connection.quote_column_name(Recipe.primary_key)}
          IN (#{Recipe.where(id: entries.map { |entry| entry.recipe.id }).select(:id).to_sql})
      SQL
    end

    private

    def update_assignments(entries)
      [
        jsonb_case_assignment("ingredient_names", entries),
        jsonb_case_assignment("ingredient_parse_data", entries),
        vector_case_assignment("ingredients_vector", entries),
        "updated_at = NOW()"
      ].join(", ")
    end

    def jsonb_case_assignment(column_name, entries)
      case_assignment(column_name, entries) do |entry|
        "#{connection.quote(entry.public_send(column_name).to_json)}::jsonb"
      end
    end

    def vector_case_assignment(column_name, entries)
      case_assignment(column_name, entries) do |entry|
        vector = entry.public_send(column_name)
        vector.nil? ? "NULL" : "#{connection.quote(Recipe.type_for_attribute(column_name).serialize(vector))}::vector"
      end
    end

    def case_assignment(column_name, entries)
      quoted_column = connection.quote_column_name(column_name)
      qualified_id_column = "#{connection.quote_table_name(Recipe.table_name)}.#{connection.quote_column_name(Recipe.primary_key)}"
      values = entries.map do |entry|
        "WHEN #{connection.quote(entry.recipe.id)} THEN #{yield(entry)}"
      end.join(" ")

      "#{quoted_column} = CASE #{qualified_id_column} #{values} ELSE #{quoted_column} END"
    end

    def connection
      Recipe.connection
    end
  end
end
