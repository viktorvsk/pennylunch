# Narrows a recipe relation to recipes matching canonical, non-optional basket
# ingredients.
#
# Returns an `ActiveRecord::Relation<Recipe>` and leaves the relation unchanged
# when no filterable catalog ingredients are present. The default overlap
# strategy filters through `recipe_ingredients`; the vector strategy embeds the
# canonical ingredient names and filters by pgvector cosine distance.
#
# Example generated query for overlap strategy:
#   SELECT "recipes".* FROM "recipes"
#   WHERE "recipes"."id" IN (
#     SELECT "recipe_ingredients"."recipe_id"
#     FROM "recipe_ingredients"
#     WHERE "recipe_ingredients"."ingredient_id" IN (1, 2)
#   )
#
# Example generated query for vector strategy:
#   SELECT "recipes".* FROM "recipes"
#   WHERE "recipes"."id" IN (
#     SELECT "recipes"."id" FROM "recipes"
#     WHERE "recipes"."ingredients_vector" IS NOT NULL
#       AND "recipes"."ingredients_vector" <=> '[...]' <= 0.35
#   )
class RecipeIngredientFilterQuery
  SEARCH_STRATEGY_CACHE_KEY = "search_strategy"
  STRATEGIES = %w[overlap vector].freeze
  VECTOR_SEARCH_STRATEGY = "vector"

  class << self
    def call(relation:, ingredients:)
      filterable_ingredients = Ingredient.filterable_matches(ingredients)
      return relation if filterable_ingredients.empty?

      if Rails.cache.read(SEARCH_STRATEGY_CACHE_KEY) == VECTOR_SEARCH_STRATEGY
        vector = LocalEmbedding.call(filterable_ingredients.map(&:name).join("\n"))
        threshold = SETTINGS.ingredients_max_cosine_distance.to_f
        ids = relation
          .where.not(ingredients_vector: nil)
          .nearest_neighbors(:ingredients_vector, vector, distance: "cosine", threshold: (threshold if threshold.positive?))
          .reselect(:id)
          .unscope(:order)

        relation.where(id: ids)
      else
        ids = RecipeIngredient.where(ingredient_id: filterable_ingredients.map(&:id)).select(:recipe_id)
        relation.where(id: ids)
      end
    end
  end
end
