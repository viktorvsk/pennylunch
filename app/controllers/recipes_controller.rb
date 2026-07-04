class RecipesController < ApplicationController
  FILTER_KEYS = %i[q category ingredients quick popular sort page].freeze

  def index
    return redirect_category_query if params[:category].present?

    render_index
  end

  def show
    if (category = Recipes::CategoryCatalogQuery.from_slug(params[:slug]))
      render_index(category:)
      return
    end

    page = Recipes::ShowPage.new(slug: params[:slug]).call
    @recipe_fab_filters = {}
    @recipe_ingredient_options = page.ingredient_options
    render locals: { recipe: page.recipe, similar_recipes: page.similar_recipes }
  end

  private

  def render_index(category: nil)
    page = Recipes::IndexPage.new(params: recipe_params, category:).call
    frame_locals = frame_locals_for(page)

    if turbo_frame_request?
      render partial: "recipes/results_frame", locals: frame_locals
      return
    end

    @recipe_fab_filters = page.filters
    @recipe_ingredient_options = page.ingredient_options
    render :index, locals: frame_locals.merge(category_labels: page.category_labels)
  end

  def redirect_category_query
    category = Recipes::Category.normalize(params[:category])
    return render_index(category:) unless Recipes::CategoryCatalogQuery.from_slug(Recipes::Category.slug_for(category))

    query = recipe_params.except(:category).to_h.compact_blank
    target = "/recipes/#{Recipes::Category.slug_for(category)}"
    target = "#{target}?#{query.to_query}" if query.present?

    redirect_to target, status: :see_other
  end

  def frame_locals_for(page)
    page.frame_locals.merge(
      next_page_url: page.next_page_filters ? helpers.recipe_filter_path(page.next_page_filters) : nil
    ).except(:next_page_filters)
  end

  def recipe_params
    params.slice(*FILTER_KEYS).permit(*FILTER_KEYS)
  end
end
