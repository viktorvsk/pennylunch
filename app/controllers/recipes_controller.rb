class RecipesController < ApplicationController
  helper_method :selected_category

  FILTER_KEYS = %i[q category quick popular sort page].freeze
  PER_PAGE = 24

  def index
    @recipe_index = build_recipe_index

    if turbo_frame_request?
      render partial: "recipes/results_frame", locals: @recipe_index.results_frame_locals
    end
  end

  def show
    @recipe = Recipe.find(Recipe.id_from_param(params[:id]))
    @similar_recipes = SimilarRecipesQuery.call(recipe: @recipe)
  end

  private

  def selected_category
    slug = params[:category_slug] || params[:category]
    return if slug.blank?

    helpers.recipe_category_from_slug(slug) || raise(ActiveRecord::RecordNotFound)
  end

  def build_recipe_index
    filters = recipe_filters
    current_page = [ filters["page"].to_i, 1 ].max
    page_records = recipe_page_records(filters, current_page)

    RecipeIndexPage.new(
      filters:,
      recipes: page_records.first(PER_PAGE),
      selected_category:,
      next_page_url: next_page_url(filters, current_page, page_records)
    )
  end

  def recipe_filters
    filters = params.permit(*FILTER_KEYS, ingredients: []).to_h
    filters["ingredients"] = ingredients_basket unless filters.key?("ingredients")
    filters["category"] = selected_category
    filters
  end

  def recipe_page_records(filters, current_page)
    relation = RecipeFilterQuery.call(filters:)
    RecipeSortQuery.call(relation:, sort: filters["sort"], ingredients: filters["ingredients"])
      .offset((current_page - 1) * PER_PAGE).limit(PER_PAGE + 1).to_a
  end

  def next_page_url(filters, current_page, page_records)
    return unless page_records.size > PER_PAGE

    helpers.recipe_filter_path(filters.merge("page" => current_page + 1))
  end
end
