# Applies recipe index filters from controller/search params.
#
# Returns an `ActiveRecord::Relation<Recipe>` after composing title search,
# normalized category, quick-time, popularity, and ingredient-basket filters.
# Ingredient filtering is delegated to `RecipeIngredientFilterQuery`.
#
# Example generated query without ingredient filtering:
#   SELECT "recipes".* FROM "recipes"
#   WHERE title_search_vector @@ websearch_to_tsquery('english', 'tomato')
#     AND "recipes"."category_normalized" = 'dinner'
#     AND "recipes"."total_time" >= 1 AND "recipes"."total_time" < 30
#     AND ratings > 4.8
#   ORDER BY ts_rank_cd(title_search_vector, websearch_to_tsquery('english', 'tomato')) DESC
class RecipeFilterQuery
  QUICK_TOTAL_TIME_LIMIT = 30
  POPULAR_RATING_THRESHOLD = 4.8
  BOOLEAN = ActiveModel::Type::Boolean.new

  class << self
    def call(relation: Recipe.all, filters:)
      category = Recipe.normalize_category(filters["category"])

      relation = TitleSearchQuery.call(relation:, query: filters["q"])
      relation = relation.where(category_normalized: category) if category.present?
      relation = relation.where(total_time: 1...QUICK_TOTAL_TIME_LIMIT) if BOOLEAN.cast(filters["quick"])
      relation = relation.where("ratings > ?", POPULAR_RATING_THRESHOLD) if BOOLEAN.cast(filters["popular"])
      RecipeIngredientFilterQuery.call(relation:, ingredients: filters["ingredients"])
    end
  end
end
