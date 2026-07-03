class RecipesController < ApplicationController
  FILTER_KEYS = %i[q category ingredients quick popular sort page].freeze

  def index
    return redirect_category_query if params[:category].present?

    render_index
  end

  def show
    if (category = Recipe.category_from_slug(params[:slug]))
      render_index(category:)
      return
    end

    recipe = Recipe.find_by!(slug: params[:slug])
    similar_recipes =
      if recipe.category_normalized.present?
        Recipe.in_category(recipe.category_normalized).where.not(id: recipe.id).order(Arel.sql("RANDOM()")).limit(3)
      else
        Recipe.none
      end
    @recipe_fab_filters = {}
    @recipe_ingredient_options = Recipe.ingredient_filter_options
    render locals: { recipe:, similar_recipes: }
  end

  private

  def render_index(category: nil)
    filters = recipe_params.to_h
    selected_category = category.presence || filters["category"].presence
    filters["category"] = selected_category if selected_category
    search = Recipes::Search.new(params: filters).call
    frame_locals = {
      search:,
      recipes: search.recipes,
      selected_category:,
      filters:,
      next_page_url: search.next_page ? helpers.recipe_filter_path(filters.merge("page" => search.next_page)) : nil,
      random_category: search.category_options.sample
    }

    if turbo_frame_request?
      render partial: "recipes/results_frame", locals: frame_locals
      return
    end

    @recipe_fab_filters = filters
    @recipe_ingredient_options = Recipe.ingredient_filter_options
    render :index, locals: frame_locals.merge(
      category_labels: Recipe.category_labels
    )
  end

  def redirect_category_query
    category = Recipe.normalize_category(params[:category])
    return render_index(category:) unless Recipe.category_from_slug(Recipe.category_slug_for(category))

    query = recipe_params.except(:category).to_h.compact_blank
    target = "/recipes/#{Recipe.category_slug_for(category)}"
    target = "#{target}?#{query.to_query}" if query.present?

    redirect_to target, status: :see_other
  end

  def recipe_params
    params.slice(*FILTER_KEYS).permit(*FILTER_KEYS)
  end
end
