class RecipesController < ApplicationController
  FILTER_KEYS = %i[q category ingredients quick popular sort page].freeze
  INGREDIENT_BASKET_COOKIE = "pennylunch.ingredients".freeze
  MAX_INGREDIENT_BASKET_ITEMS = 100
  PER_PAGE = 24

  def index
    filters = recipe_filters
    @recipe_layout_fab_filters = filters.slice("ingredients")
    locals = results_locals(filters)

    if turbo_frame_request?
      render partial: "recipes/results_frame", locals:
    else
      render :index, locals:
    end
  end

  def show
    recipe = Recipe.find(Recipe.id_from_param(params[:id]))
    render locals: { recipe:, similar_recipes: SimilarRecipesQuery.call(recipe:) }
  end

  private

  def results_locals(filters)
    current_page = [ filters["page"].to_i, 1 ].max
    page_records = recipe_scope(filters).offset((current_page - 1) * PER_PAGE).limit(PER_PAGE + 1).to_a
    {
      recipes: page_records.first(PER_PAGE),
      selected_category: filters["category"],
      filters:,
      next_page_url: page_records.size > PER_PAGE ? helpers.recipe_filter_path(filters.merge("page" => current_page + 1)) : nil
    }
  end

  def recipe_scope(filters)
    relation = RecipeFilterQuery.call(filters:)
    RecipeSortQuery.call(relation:, sort: filters["sort"], ingredients: filters["ingredients"])
  end

  def recipe_filters
    filters = params.permit(*FILTER_KEYS).to_h
    basket = ingredient_basket
    filters["ingredients"] = basket if !filters.key?("ingredients") && basket.present?

    if params[:category_slug]
      filters["category"] = helpers.recipe_category_from_slug(params[:category_slug]) || raise(ActiveRecord::RecordNotFound)
    end

    filters
  end

  def ingredient_basket
    payload = JSON.parse(cookies[INGREDIENT_BASKET_COOKIE].to_s)
    return unless payload.is_a?(Hash) && ActiveModel::Type::Boolean.new.cast(payload["enabled"])

    Array(payload["selected"]).grep(String).filter_map { it.squish.presence }
      .first(MAX_INGREDIENT_BASKET_ITEMS).join("\n").presence
  rescue JSON::ParserError
    nil
  end
end
