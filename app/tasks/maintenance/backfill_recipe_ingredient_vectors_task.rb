module Maintenance
  class BackfillRecipeIngredientVectorsTask < MaintenanceTasks::Task
    BATCH_SIZE = 128
    ParserResult = Data.define(:ingredient_names, :ingredient_parse_data, :ingredients_vector_names)

    def collection
      Recipe.in_batches(of: BATCH_SIZE)
    end

    def process(records)
      recipes = records.is_a?(Recipe) ? [ records ] : records.to_a
      vector_ingredient_lookup = Ingredient.filterable_lookup_map
      parser_results = IngredientParser.call(recipes.map(&:ingredients)).map { |parser_result| canonical_parser_result(parser_result, vector_ingredient_lookup) }
      recipes_requiring_vectors = recipes.zip(parser_results).select do |recipe, parser_result|
        recipe.ingredients_vector.nil? || recipe.ingredient_names != parser_result.ingredient_names || recipe.ingredients_vector_names != parser_result.ingredients_vector_names
      end
      vectors = vectors_for(recipes_requiring_vectors)

      recipes.zip(parser_results).each do |recipe, parser_result|
        attributes = {
          ingredient_names: parser_result.ingredient_names,
          ingredients_vector_names: parser_result.ingredients_vector_names,
          ingredient_parse_data: parser_result.ingredient_parse_data
        }
        attributes[:ingredients_vector] = vectors.fetch(recipe.id) if vectors.key?(recipe.id)
        recipe.update!(attributes)
      end
    end

    private

    def canonical_parser_result(parser_result, vector_ingredient_lookup)
      ParserResult.new(
        parser_result.ingredient_names.filter_map { |name| name.to_s.squish.downcase.presence }.uniq,
        parser_result.ingredient_parse_data,
        parser_result.ingredient_names.filter_map { |name| vector_ingredient_lookup[Ingredient.normalize_lookup_key(name)] }.uniq
      )
    end

    def vectors_for(recipes_with_results)
      return {} if recipes_with_results.empty?

      recipes_with_names = recipes_with_results.select { |_recipe, parser_result| parser_result.ingredients_vector_names.any? }
      return recipes_with_results.to_h { |(recipe, _parser_result)| [ recipe.id, nil ] } if recipes_with_names.empty?

      vectors = LocalEmbedding.call(recipes_with_names.map { |_recipe, parser_result| parser_result.ingredients_vector_names.join("\n") })
      empty_vectors = (recipes_with_results - recipes_with_names).to_h { |(recipe, _parser_result)| [ recipe.id, nil ] }
      embedded_vectors = recipes_with_names.zip(vectors).to_h { |(recipe, _parser_result), vector| [ recipe.id, vector ] }
      empty_vectors.merge(embedded_vectors)
    end
  end
end
