class RecipeSearch
  Result = Data.define(:recipes, :page, :next_page)
  DEFAULT_PAGE = 1
  PER_PAGE = 24
  DEFAULT_SORT = "time_asc"
  QUICK_TOTAL_TIME_LIMIT = 30
  POPULAR_RATING_THRESHOLD = 4.8
  UNKNOWN_TIME_FIRST_SQL = "CASE WHEN total_time = 0 THEN 0 ELSE 1 END ASC"
  UNKNOWN_TIME_LAST_SQL = "CASE WHEN total_time = 0 THEN 1 ELSE 0 END ASC"

  def initialize(params:, embedder: LocalEmbedding, ingredient_parser: IngredientParser)
    @params = params.to_h.with_indifferent_access
    @embedder = embedder
    @ingredient_parser = ingredient_parser
  end

  def call
    boolean = ActiveModel::Type::Boolean.new
    category = Recipe.normalize_category(params[:category])

    relation = Recipes::TitleSearchQuery.call(relation: Recipe.all, query: params[:q])
    relation = relation.where(category_normalized: category) if category.present?
    relation = relation.where("total_time > 0 AND total_time < ?", QUICK_TOTAL_TIME_LIMIT) if boolean.cast(params[:quick])
    relation = relation.where("ratings > ?", POPULAR_RATING_THRESHOLD) if boolean.cast(params[:popular])
    relation = filter_by_ingredients(relation)
    relation =
      case params[:sort].to_s
      when "time_desc"
        relation.order(Arel.sql(UNKNOWN_TIME_FIRST_SQL), total_time: :desc, id: :asc)
      when "rating_asc"
        relation.order(ratings: :asc, id: :asc)
      when "rating_desc"
        relation.order(ratings: :desc, id: :asc)
      else
        relation.order(Arel.sql(UNKNOWN_TIME_LAST_SQL), total_time: :asc, id: :asc)
      end

    current_page = page
    page_records = relation.offset((current_page - 1) * PER_PAGE).limit(PER_PAGE + 1).to_a

    Result.new(
      recipes: page_records.first(PER_PAGE),
      page: current_page,
      next_page: page_records.size > PER_PAGE ? current_page + 1 : nil
    )
  end

  private

  attr_reader :params, :embedder, :ingredient_parser

  def filter_by_ingredients(relation)
    text = params[:ingredients].to_s
    return relation if text.blank?

    case SETTINGS.ingredients_filter_strategy.to_s
    when "naive_vector_search"
      filter_by_ingredient_vector(relation, text)
    else
      raise ArgumentError, "unsupported ingredients filter strategy: #{SETTINGS.ingredients_filter_strategy}"
    end
  end

  def filter_by_ingredient_vector(relation, text)
    query_names = query_ingredient_names(text)
    return relation if query_names.empty?

    Recipes::IngredientCandidateQuery.call(
      relation:,
      vector: embedder.call(query_names.join("\n"))
    )
  end

  def query_ingredient_names(text)
    lines = text.split(/[\n,;]+/).filter_map { |line| line.squish.presence }
    parser_result = ingredient_parser.call([ lines ]).first
    Ingredient.filterable_canonical_names_for(lines + parser_result.ingredient_names)
  end

  def page
    value = params[:page].to_i
    value.positive? ? value : DEFAULT_PAGE
  end
end
