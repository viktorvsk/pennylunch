class RecipesController < ApplicationController
  helper_method :selected_category

  FILTER_KEYS = %i[q category quick popular sort page].freeze
  PER_PAGE = 24

  def index
    @filters = recipe_filters

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
    filters = params.permit(*FILTER_KEYS, ingredients: []).to_h
    filters["ingredients"] = ingredients_basket unless filters.key?("ingredients")
    filters["category"] = selected_category
    filters
  end
end
