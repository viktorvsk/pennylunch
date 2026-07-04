class RecipesController < ApplicationController
  FILTER_KEYS = %i[q category ingredients quick popular sort page].freeze
  INGREDIENT_BASKET_COOKIE = "pennylunch.ingredients".freeze
  MAX_INGREDIENT_BASKET_COOKIE_BYTES = 4096
  MAX_INGREDIENT_BASKET_ITEMS = 100
  DEFAULT_PAGE = 1
  PER_PAGE = 24
  DEFAULT_SORT = "best_match"
  QUICK_TOTAL_TIME_LIMIT = 30
  POPULAR_RATING_THRESHOLD = 4.8
  UNKNOWN_TIME_LAST_SQL = "CASE WHEN total_time = 0 THEN 1 ELSE 0 END DESC"

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
    boolean = ActiveModel::Type::Boolean.new
    category = Recipe.normalize_category(recipe_params["category"])

    relation = TitleSearchQuery.call(relation: Recipe.all, query: recipe_params["q"])
    relation = relation.where(category_normalized: category) if category.present?
    relation = relation.where("total_time > 0 AND total_time < ?", QUICK_TOTAL_TIME_LIMIT) if boolean.cast(recipe_params["quick"])
    relation = relation.where("ratings > ?", POPULAR_RATING_THRESHOLD) if boolean.cast(recipe_params["popular"])
    relation = RecipeSearch.call(relation:, ingredients: recipe_params["ingredients"])

    case recipe_params["sort"].presence || DEFAULT_SORT
    when "time_desc"
      relation.reorder(Arel.sql(UNKNOWN_TIME_LAST_SQL), total_time: :desc, id: :asc)
    when "time_asc"
      relation.reorder(Arel.sql(UNKNOWN_TIME_LAST_SQL), total_time: :asc, id: :asc)
    when "rating_asc"
      relation.reorder(ratings: :asc, id: :asc)
    when "rating_desc"
      relation.reorder(ratings: :desc, id: :asc)
    else
      RecipeSearch.order_by_best_match(relation, ingredients: recipe_params["ingredients"]).order(ratings: :desc, total_time: :asc, id: :asc)
    end
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
