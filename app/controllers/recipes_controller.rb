class RecipesController < ApplicationController
  helper_method :selected_category

  FILTER_KEYS = %i[q category ingredients quick popular sort page].freeze
  INGREDIENT_BASKET_COOKIE = "pennylunch.ingredients".freeze
  MAX_INGREDIENT_BASKET_ITEMS = 100
  PER_PAGE = 24

  def index
    @filters = recipe_filters
    @recipe_layout_fab_filters = @filters.slice("ingredients")

    current_page = [ @filters["page"].to_i, 1 ].max
    relation = RecipeFilterQuery.call(filters: @filters)
    page_records = RecipeSortQuery.call(relation:, sort: @filters["sort"], ingredients: @filters["ingredients"])
      .offset((current_page - 1) * PER_PAGE).limit(PER_PAGE + 1).to_a

    @recipes = page_records.first(PER_PAGE)
    @next_page_url = (@filters.merge("page" => current_page + 1) if page_records.size > PER_PAGE)

    if turbo_frame_request?
      render partial: "recipes/results_frame", locals: {
        recipes: @recipes,
        selected_category: selected_category,
        filters: @filters,
        next_page_url: @next_page_url ? helpers.recipe_filter_path(@next_page_url) : nil
      }
    end
  end

  def show
    @recipe = Recipe.find(Recipe.id_from_param(params[:id]))
    @similar_recipes = SimilarRecipesQuery.call(recipe: @recipe)
  end

  private

  def selected_category
    @selected_category ||=
      begin
        slug = params[:category_slug] || params[:category]
        if slug.present?
          helpers.recipe_category_from_slug(slug) || raise(ActiveRecord::RecordNotFound)
        end
      end
  end

  def recipe_filters
    filters = params.permit(*FILTER_KEYS).to_h
    check_basket(filters)
    filters["category"] = selected_category
    filters
  end

  def check_basket(filters)
    return if filters.key?("ingredients")

    payload = JSON.parse(cookies[INGREDIENT_BASKET_COOKIE].to_s)
    return unless payload.is_a?(Hash) && payload["enabled"]

    names = Array(payload["selected"]).map(&:squish).compact_blank.first(MAX_INGREDIENT_BASKET_ITEMS)
    filters["ingredients"] = names.join("\n")
  rescue JSON::ParserError
    nil
  end
end
