class RecipesController < ApplicationController
  FILTER_KEYS = %i[q category ingredients quick popular sort page].freeze
  DEFAULT_PAGE = 1
  PER_PAGE = 24
  DEFAULT_SORT = "time_asc"
  QUICK_TOTAL_TIME_LIMIT = 30
  POPULAR_RATING_THRESHOLD = 4.8
  UNKNOWN_TIME_LAST_SQL = "CASE WHEN total_time = 0 THEN 1 ELSE 0 END ASC"

  def index
    if turbo_frame_request?
      render partial: "recipes/results_frame", locals: frame_locals
      return
    end

    render :index, locals: frame_locals
  end

  def show
    recipe = Recipe.find(params[:id].to_s.rpartition("-").last)
    render locals: { recipe:, similar_recipes: SimilarRecipesQuery.call(recipe:) }
  end

  private

  def frame_locals
    @frame_locals ||= begin
      current_page = page
      page_records = recipe_scope.offset((current_page - 1) * PER_PAGE).limit(PER_PAGE + 1).to_a
      {
        recipes: page_records.first(PER_PAGE),
        selected_category: recipe_params["category"],
        filters: recipe_params,
        next_page_url: page_records.size > PER_PAGE ? helpers.recipe_filter_path(recipe_params.merge("page" => current_page + 1)) : nil
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

    case recipe_params["sort"].to_s
    when "time_desc"
      relation.order(Arel.sql(UNKNOWN_TIME_LAST_SQL), total_time: :desc, id: :asc)
    when "rating_asc"
      relation.order(ratings: :asc, id: :asc)
    when "rating_desc"
      relation.order(ratings: :desc, id: :asc)
    else
      relation.order(ratings: :desc, total_time: :asc, id: :asc)
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

  def page
    value = recipe_params["page"].to_i
    value.positive? ? value : DEFAULT_PAGE
  end
end
