module Recipes
  class TitleSearchQuery
    TITLE_RANK_SQL = "ts_rank_cd(title_search_vector, websearch_to_tsquery('english', ?)) DESC"
    TITLE_MATCH_SQL = "title_search_vector @@ websearch_to_tsquery('english', ?)"

    def self.call(relation:, query:)
      query.present? ? new(relation:, query:).call : relation
    end

    def initialize(relation:, query:)
      @relation = relation
      @query = query
    end

    def call
      relation.where(TITLE_MATCH_SQL, query).order(Arel.sql(rank_sql))
    end

    private

    attr_reader :relation, :query

    def rank_sql
      Recipe.sanitize_sql_array([ TITLE_RANK_SQL, query ])
    end
  end
end
