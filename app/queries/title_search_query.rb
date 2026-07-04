# Adds PostgreSQL web-search title matching and relevance ranking.
#
# Returns the original `ActiveRecord::Relation<Recipe>` when `query` is blank;
# otherwise returns a relation filtered by `title_search_vector` and ordered by
# `ts_rank_cd`.
#
# Example generated query:
#   SELECT "recipes".* FROM "recipes"
#   WHERE title_search_vector @@ websearch_to_tsquery('english', 'tomato pasta')
#   ORDER BY ts_rank_cd(title_search_vector, websearch_to_tsquery('english', 'tomato pasta')) DESC
class TitleSearchQuery
  TITLE_MATCH_SQL = "title_search_vector @@ websearch_to_tsquery('english', ?)"
  TITLE_RANK_SQL = "ts_rank_cd(title_search_vector, websearch_to_tsquery('english', ?)) DESC"

  class << self
    def call(relation:, query:)
      return relation if query.blank?

      relation
        .where(TITLE_MATCH_SQL, query)
        .order(Arel.sql(Recipe.sanitize_sql_array([ TITLE_RANK_SQL, query ])))
    end
  end
end
