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
  TITLE_MATCH_SQL = "title_search_vector @@ websearch_to_tsquery('english', ?)"
  TITLE_RANK_SQL = "ts_rank_cd(title_search_vector, websearch_to_tsquery('english', ?)) DESC"

  class << self
    def call(filters:)
      relation = Recipe.all
      category = Recipe.normalize_category(filters["category"])
      query = filters["q"]
      boolean = ActiveModel::Type::Boolean.new

      if query.present?
        relation = relation
        .where(TITLE_MATCH_SQL, query)
        .order(Arel.sql(Recipe.sanitize_sql_array([ TITLE_RANK_SQL, query ])))
      end
      relation = relation.where(category_normalized: category) if category.present?
      relation = relation.where(total_time: 1...QUICK_TOTAL_TIME_LIMIT) if boolean.cast(filters["quick"])
      relation = relation.where("ratings > ?", POPULAR_RATING_THRESHOLD) if boolean.cast(filters["popular"])
      RecipeIngredientFilterQuery.call(relation:, ingredients: filters["ingredients"])
    end
  end
end
