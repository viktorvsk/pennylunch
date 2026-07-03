module Maintenance
  class BackfillRecipeIngredientVectorsTask < MaintenanceTasks::Task
    BATCH_SIZE = 128

    def collection
      Recipe.where("ingredients_vector IS NULL OR ingredient_names = ARRAY[]::text[] OR ingredient_parse_data = '[]'::jsonb").in_batches(of: BATCH_SIZE)
    end

    def process(records)
      recipes = records.is_a?(Recipe) ? [ records ] : records.to_a
      parser_results = IngredientParser.call(recipes.map(&:ingredients))
      recipes_requiring_vectors = recipes.zip(parser_results).select do |recipe, parser_result|
        recipe.ingredients_vector.nil? || recipe.ingredient_names.blank? || recipe.ingredient_names != parser_result.ingredient_names
      end
      vectors = vectors_for(recipes_requiring_vectors)

      recipes.zip(parser_results).each do |recipe, parser_result|
        attributes = {
          ingredient_names: parser_result.ingredient_names,
          ingredient_parse_data: parser_result.ingredient_parse_data
        }
        attributes[:ingredients_vector] = vectors.fetch(recipe.id) if vectors.key?(recipe.id)
        recipe.update!(attributes)
      end
    end

    private

    def vectors_for(recipes_with_results)
      return {} if recipes_with_results.empty?

      vectors = LocalEmbedding.call(recipes_with_results.map { |_recipe, parser_result| parser_result.ingredient_names.join("\n") })
      recipes_with_results.zip(vectors).to_h { |(recipe, _parser_result), vector| [ recipe.id, vector ] }
    end
  end
end
