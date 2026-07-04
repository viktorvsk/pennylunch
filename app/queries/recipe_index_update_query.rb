class RecipeIndexUpdateQuery
  class << self
    def call(entries:)
      connection = Recipe.connection
      vector_type = Recipe.type_for_attribute("ingredients_vector")

      rows = entries.map do |entry|
        id = connection.quote(entry.recipe.id)
        names = connection.quote(entry.ingredient_names.to_json)
        parse = connection.quote(entry.ingredient_parse_data.to_json)
        vector = entry.ingredients_vector
        vector_val = vector.nil? ? "NULL::vector" : "#{connection.quote(vector_type.serialize(vector))}::vector"

        "(#{id}, #{names}::jsonb, #{parse}::jsonb, #{vector_val})"
      end.join(", ")

      <<~SQL.squish
        UPDATE "recipes"
        SET
          ingredient_names = data.ingredient_names,
          ingredient_parse_data = data.ingredient_parse_data,
          ingredients_vector = data.ingredients_vector,
          updated_at = NOW()
        FROM (VALUES #{rows}) AS data(id, ingredient_names, ingredient_parse_data, ingredients_vector)
        WHERE "recipes".id = data.id
      SQL
    end
  end
end
