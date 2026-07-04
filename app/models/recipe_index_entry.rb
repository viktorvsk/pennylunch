class RecipeIndexEntry < Data.define(:recipe, :ingredient_names, :ingredient_parse_data, :ingredients_vector)
  class << self
    def from(recipe:, parser_result:, ingredient_lookup:)
      ingredient_names = parser_result.ingredient_names.filter_map { |name| name.to_s.squish.downcase.presence }.uniq
      vector_names = ingredient_names.filter_map { |name| ingredient_lookup[name] }.uniq

      new(
        recipe:,
        ingredient_names:,
        ingredient_parse_data: parser_result.ingredient_parse_data,
        ingredients_vector: vector_names.any? ? LocalEmbedding.call(vector_names.join("\n")) : nil
      )
    end
  end
end
