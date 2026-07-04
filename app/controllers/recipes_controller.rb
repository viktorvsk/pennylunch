class RecipesController < ApplicationController
  FILTER_KEYS = %i[q category ingredients quick popular sort page].freeze

  def index
    if turbo_frame_request?
      render partial: "recipes/results_frame", locals: frame_locals
      return
    end

    render :index, locals: frame_locals
  end

  def show
    recipe = Recipe.find(params[:id].to_s.rpartition("-").last)
    render locals: { recipe:, similar_recipes: Recipes::SimilarRecipesQuery.call(recipe:) }
  end

  private

  def frame_locals
    @frame_locals ||= begin
      search = RecipeSearch.new(params: recipe_params).call
      {
        search:,
        recipes: search.recipes,
        selected_category: recipe_params["category"],
        filters: recipe_params,
        next_page_url: search.next_page ? helpers.recipe_filter_path(recipe_params.merge("page" => search.next_page)) : nil
      }
    end
  end

  def recipe_params
    @recipe_params ||= begin
      filters = params.slice(*FILTER_KEYS).permit(*FILTER_KEYS)

      selected_category = params[:category_slug].present? ? helpers.recipe_category_from_slug(params[:category_slug]) : filters["category"].presence
      raise ActiveRecord::RecordNotFound if params[:category_slug].present? && selected_category.blank?

      filters["category"] = selected_category if selected_category

      filters
    end
  end
end
