module Recipes
  class Search
    Result = Data.define(:recipes, :page, :previous_page, :next_page, :total_count, :category_options)
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
      relation = Recipe.all
      relation = relation.matching_title(param(:q))
      relation = relation.in_category(param(:category))
      relation = relation.quick if active?(:quick)
      relation = relation.popular if active?(:popular)
      relation = Recipes::FilterIngredients.new(
        relation:,
        text: param(:ingredients),
        options: ingredients_filter_options,
      ).call
      relation = Recipe.sort_relation(relation, param(:sort))

      total_count = relation.count
      current_page = page
      recipes = relation.offset((current_page - 1) * PER_PAGE).limit(PER_PAGE).to_a

      Result.new(
        recipes:,
        page: current_page,
        previous_page: current_page > 1 ? current_page - 1 : nil,
        next_page: current_page * PER_PAGE < total_count ? current_page + 1 : nil,
        total_count:,
        category_options: Recipe.category_options,
      )
    end

    private

    attr_reader :params, :ingredients_filter_options

    def param(name)
      params[name] || params[name.to_s]
    end

    def active?(name)
      param(name).to_s == "1"
    end

    def page
      value = param(:page).to_i
      value.positive? ? value : 1
    end
  end
end
