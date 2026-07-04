class RecipeIndexUpdateQuery
  class << self
    def call(entries:)
      connection = Recipe.connection
      table = connection.quote_table_name(Recipe.table_name)
      primary_key = connection.quote_column_name(Recipe.primary_key)
      id_column = "#{table}.#{primary_key}"
      ingredient_names_cases = entries.map do |entry|
        "WHEN #{connection.quote(entry.recipe.id)} THEN #{connection.quote(entry.ingredient_names.to_json)}::jsonb"
      end.join(" ")
      ingredient_parse_data_cases = entries.map do |entry|
        "WHEN #{connection.quote(entry.recipe.id)} THEN #{connection.quote(entry.ingredient_parse_data.to_json)}::jsonb"
      end.join(" ")
      vector_cases = entries.map do |entry|
        vector = entry.ingredients_vector
        value = vector.nil? ? "NULL" : "#{connection.quote(Recipe.type_for_attribute("ingredients_vector").serialize(vector))}::vector"

        "WHEN #{connection.quote(entry.recipe.id)} THEN #{value}"
      end.join(" ")

      <<~SQL.squish
        UPDATE #{table}
        SET
          ingredient_names = CASE #{id_column} #{ingredient_names_cases} ELSE ingredient_names END,
          ingredient_parse_data = CASE #{id_column} #{ingredient_parse_data_cases} ELSE ingredient_parse_data END,
          ingredients_vector = CASE #{id_column} #{vector_cases} ELSE ingredients_vector END,
          updated_at = NOW()
        WHERE #{id_column}
          IN (#{Recipe.where(id: entries.map { |entry| entry.recipe.id }).select(:id).to_sql})
      SQL
    end
  end
end
