module Maintenance
  # Rebuilds the derived ingredient search fields for imported recipes.
  #
  # What it changes:
  # - `ingredient_names`, using the current parser output for each source ingredient line.
  # - `ingredient_parse_data`, preserving the structured parser data used by the recipe show page.
  # - `ingredients_vector`, using only non-optional canonical Ingredient names resolved from the catalog.
  #
  # Why this exists:
  # Recipe import keeps the original source ingredient strings intact, while search depends on derived
  # parser and catalog data. Running this task after import, parser changes, or Ingredient catalog changes
  # brings the recipe rows back in sync without changing the source-fidelity columns.
  #
  # How it works:
  # The task processes recipes in Active Record batches, parses each batch with one IngredientParser call,
  # resolves parser names through the current non-optional Ingredient lookup, embeds the canonical names,
  # and writes the derived fields back to each recipe.
  class BackfillRecipeIngredientVectorsTask < MaintenanceTasks::Task
    BATCH_SIZE = 128

    def collection
      Recipe.in_batches(of: BATCH_SIZE)
    end

    def process(records)
      recipes = records.is_a?(Recipe) ? [ records ] : records.to_a
      vector_ingredient_lookup = Ingredient.filterable_lookup_map
      parser_results = IngredientParser.call(recipes.map(&:ingredients)).map { |parser_result| canonical_parser_result(parser_result, vector_ingredient_lookup) }
      vectors = vectors_for(recipes.zip(parser_results))

      recipes.zip(parser_results).each do |recipe, parser_result|
        recipe.update!(
          ingredient_names: parser_result.fetch(:ingredient_names),
          ingredient_parse_data: parser_result.fetch(:ingredient_parse_data),
          ingredients_vector: vectors.fetch(recipe.id)
        )
      end
    end

    private

    def canonical_parser_result(parser_result, vector_ingredient_lookup)
      {
        ingredient_names: parser_result.ingredient_names.filter_map { |name| name.to_s.squish.downcase.presence }.uniq,
        ingredient_parse_data: parser_result.ingredient_parse_data,
        embedding_names: parser_result.ingredient_names.filter_map { |name| vector_ingredient_lookup[Ingredient.normalize_lookup_key(name)] }.uniq
      }
    end

    def vectors_for(recipes_with_parser_results)
      return {} if recipes_with_parser_results.empty?

      recipes_with_names = recipes_with_parser_results.select { |_recipe, parser_result| parser_result.fetch(:embedding_names).any? }
      return recipes_with_parser_results.to_h { |(recipe, _parser_result)| [ recipe.id, nil ] } if recipes_with_names.empty?

      vectors = LocalEmbedding.call(recipes_with_names.map { |_recipe, parser_result| parser_result.fetch(:embedding_names).join("\n") })
      empty_vectors = (recipes_with_parser_results - recipes_with_names).to_h { |(recipe, _parser_result)| [ recipe.id, nil ] }
      embedded_vectors = recipes_with_names.zip(vectors).to_h { |(recipe, _parser_result), vector| [ recipe.id, vector ] }
      empty_vectors.merge(embedded_vectors)
    end
  end
end
