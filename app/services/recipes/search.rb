module Recipes
  class Search
    Result = Data.define(:recipes, :page, :next_page, :category_options)
    PER_PAGE = 24

    def initialize(params:, embedder: LocalEmbedding, ingredient_parser: IngredientParser, ingredients_candidate_count: Rails.application.config.penny_lunch.ingredients_candidate_count, ingredients_max_distance: Rails.application.config.penny_lunch.ingredients_max_cosine_distance)
      @params = params
      @ingredients_filter_options = {
        embedder:,
        ingredient_parser:,
        candidate_count: ingredients_candidate_count.to_i,
        max_distance: ingredients_max_distance.to_f
      }
    end

    def call
      relation = Recipes::RelationQuery.call(params:)
      relation = Recipes::FilterIngredients.new(
        relation:,
        text: param(:ingredients),
        options: ingredients_filter_options,
      ).call
      relation = Recipes::RelationQuery.sort(relation, param(:sort))

      current_page = page
      page_records = relation.offset((current_page - 1) * PER_PAGE).limit(PER_PAGE + 1).to_a

      Result.new(
        recipes: page_records.first(PER_PAGE),
        page: current_page,
        next_page: page_records.size > PER_PAGE ? current_page + 1 : nil,
        category_options: Recipes::CategoryCatalogQuery.options
      )
    end

    private

    attr_reader :params, :ingredients_filter_options

    def param(name)
      params[name] || params[name.to_s]
    end

    def page
      value = param(:page).to_i
      value.positive? ? value : Recipes::FilterValues::DEFAULT_PAGE
    end
  end
end
