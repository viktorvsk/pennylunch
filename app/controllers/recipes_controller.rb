class RecipesController < ApplicationController
  FILTER_KEYS = %i[q category ingredients quick popular sort page].freeze
  INGREDIENT_BASKET_COOKIE = "pennylunch.ingredients".freeze
  MAX_INGREDIENT_BASKET_COOKIE_BYTES = 4096
  MAX_INGREDIENT_BASKET_ITEMS = 100
  DEFAULT_PAGE = 1
  PER_PAGE = 24

  def index
    if turbo_frame_request?
      render partial: "recipes/results_frame", locals: frame_locals
      return
    end

    render :index, locals: frame_locals
  end

  def show
    recipe = Recipe.find(Recipe.id_from_param(params[:id]))
    render locals: { recipe:, similar_recipes: SimilarRecipesQuery.call(recipe:) }
  end

  private

  def frame_locals
    @frame_locals ||= begin
      current_page = page
      filters = recipe_params
      @recipe_layout_fab_filters = filters.slice("ingredients")
      page_records = recipe_scope.offset((current_page - 1) * PER_PAGE).limit(PER_PAGE + 1).to_a
      {
        recipes: page_records.first(PER_PAGE),
        selected_category: filters["category"],
        filters:,
        next_page_url: page_records.size > PER_PAGE ? helpers.recipe_filter_path(filters.merge("page" => current_page + 1)) : nil
      }
    end
  end

  def recipe_scope
    relation = RecipeFilterQuery.call(filters: recipe_params)
    RecipeSortQuery.call(relation:, sort: recipe_params["sort"], ingredients: recipe_params["ingredients"])
  end

  def recipe_params
    @recipe_params ||= begin
      filters = params.slice(*FILTER_KEYS).permit(*FILTER_KEYS)
      cookie_ingredients = ingredient_basket_cookie_filter
      filters["ingredients"] = cookie_ingredients if !filters.key?("ingredients") && cookie_ingredients.present?

      selected_category = params[:category_slug].present? ? helpers.recipe_category_from_slug(params[:category_slug]) : filters["category"].presence
      raise ActiveRecord::RecordNotFound if params[:category_slug].present? && selected_category.blank?

      filters["category"] = selected_category if selected_category

      filters
    end
  end

  def ingredient_basket_cookie_filter
    value = cookies[INGREDIENT_BASKET_COOKIE].to_s
    return if value.blank? || value.bytesize > MAX_INGREDIENT_BASKET_COOKIE_BYTES

    payload = parse_ingredient_basket_cookie(value)
    return unless payload.is_a?(Hash)
    return unless ActiveModel::Type::Boolean.new.cast(payload["enabled"])

    selected = payload["selected"]
    return unless selected.is_a?(Array)

    selected.filter_map { |name| name.squish.presence if name.is_a?(String) }.first(MAX_INGREDIENT_BASKET_ITEMS).join("\n").presence
  rescue JSON::ParserError, TypeError
    nil
  end

  def parse_ingredient_basket_cookie(value)
    JSON.parse(value)
  rescue JSON::ParserError
    JSON.parse(Rack::Utils.unescape(value))
  end

  def page
    value = recipe_params["page"].to_i
    value.positive? ? value : DEFAULT_PAGE
  end
end
