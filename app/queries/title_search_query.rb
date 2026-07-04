# Returns a relation filtered and ranked by PostgreSQL full-text title search.
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
