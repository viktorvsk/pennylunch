module Recipes
  class IndexPage
    Result = Data.define(
      :search,
      :recipes,
      :selected_category,
      :filters,
      :next_page_filters,
      :random_category,
      :category_labels,
      :ingredient_options
    ) do
      def frame_locals
        {
          search:,
          recipes:,
          selected_category:,
          filters:,
          next_page_filters:,
          random_category:
        }
      end

      def index_locals
        frame_locals.merge(category_labels:)
      end
    end

    def initialize(params:, category: nil, category_catalog: Recipes::CategoryCatalogQuery.new)
      @params = params.to_h
      @category = category
      @category_catalog = category_catalog
    end

    def call
      filters = params.dup
      selected_category = category.presence || filters["category"].presence
      filters["category"] = selected_category if selected_category
      search = Recipes::Search.new(params: filters).call

      Result.new(
        search:,
        recipes: search.recipes,
        selected_category:,
        filters:,
        next_page_filters: next_page_filters(search, filters),
        random_category: search.category_options.sample,
        category_labels: category_catalog.labels,
        ingredient_options: Ingredient.filter_options
      )
    end

    private

    attr_reader :params, :category, :category_catalog

    def next_page_filters(search, filters)
      return unless search.next_page

      filters.merge("page" => search.next_page)
    end
  end
end
