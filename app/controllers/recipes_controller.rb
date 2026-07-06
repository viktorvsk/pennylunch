class RecipesController < ApplicationController
  MAX_COOKIE_INGREDIENTS = 100
  PER_PAGE = 24

  def index
    category = selected_category
    filters = params.permit(:q, :category, :quick, :popular, :sort, :page, ingredients: []).to_h
    unless filters.key?("ingredients")
      payload = JSON.parse(cookies["pennylunch.ingredients"].to_s) rescue nil
      filters["ingredients"] = Array(payload["selected"]).map(&:squish).compact_blank.first(MAX_COOKIE_INGREDIENTS) if payload.is_a?(Hash) && payload["enabled"] == true
    end
    filters["category"] = category
    current_page = [ filters["page"].to_i, 1 ].max
    recipes = RecipeSortQuery
      .call(relation: RecipeFilterQuery.call(filters:), sort: filters["sort"], ingredients: filters["ingredients"])
      .offset((current_page - 1) * PER_PAGE)
      .limit(PER_PAGE + 1)
      .to_a
    next_page_url = helpers.recipe_filter_path(filters.merge("page" => current_page + 1)) if recipes.size > PER_PAGE
    page = {
      recipes: recipes.first(PER_PAGE),
      selected_category: category,
      filters:,
      next_page_url:
    }
    @ingredients_fab_filters = filters.slice("ingredients")

    if turbo_frame_request?
      render partial: "recipes/results_frame", locals: page
    else
      render :index, locals: page
    end
  end

  def show
    @recipe = Recipe.find(Recipe.id_from_param(params[:id]))
  end

  private

  def selected_category
    slug = params[:category_slug] || params[:category]
    return if slug.blank?

    helpers.recipe_catalog[:category_slugs].key(slug.to_s) || raise(ActiveRecord::RecordNotFound)
  end
end
