class RecipeIndexEntry < Data.define(:recipe, :ingredient_names, :ingredient_parse_data, :ingredients_vector)
  def self.from(recipe:, parser_result:, ingredient_lookup:)
    vector_names = parser_result.ingredient_names.filter_map { ingredient_lookup[it] }.uniq

    new(
      recipe:,
      ingredient_names: parser_result.ingredient_names,
      ingredient_parse_data: parser_result.ingredient_parse_data,
      ingredients_vector: LocalEmbedding.call(vector_names.join("\n"))
    )
  end
end
