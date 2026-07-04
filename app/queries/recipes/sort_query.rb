module Recipes
  class SortQuery
    DEFAULT_SORT = "time_asc"
    UNKNOWN_TIME_FIRST_SQL = "CASE WHEN total_time = 0 THEN 0 ELSE 1 END ASC"
    UNKNOWN_TIME_LAST_SQL = "CASE WHEN total_time = 0 THEN 1 ELSE 0 END ASC"
    SORT_ORDERS = {
      "time_asc" => ->(relation) { relation.order(Arel.sql(UNKNOWN_TIME_LAST_SQL), total_time: :asc, id: :asc) },
      "time_desc" => ->(relation) { relation.order(Arel.sql(UNKNOWN_TIME_FIRST_SQL), total_time: :desc, id: :asc) },
      "rating_asc" => ->(relation) { relation.order(ratings: :asc, id: :asc) },
      "rating_desc" => ->(relation) { relation.order(ratings: :desc, id: :asc) }
    }.freeze

    def self.call(relation:, sort:)
      sort_key = SORT_ORDERS.key?(sort.to_s) ? sort.to_s : DEFAULT_SORT
      SORT_ORDERS.fetch(sort_key).call(relation)
    end
  end
end
