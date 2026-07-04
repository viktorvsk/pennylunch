class RecipeSearch
  Result = Data.define(:recipes, :page, :next_page, :category_options)
  DEFAULT_PAGE = 1
  PER_PAGE = 24

  def initialize(params:, embedder: LocalEmbedding, ingredient_parser: IngredientParser)
    @params = params
    @embedder = embedder
    @ingredient_parser = ingredient_parser
  end

  def call
    relation = Recipes::RelationQuery.call(params:)
    relation = filter_by_ingredients(relation)
    relation = Recipes::RelationQuery.sort(relation, param(:sort))

    current_page = page
    page_records = relation.offset((current_page - 1) * PER_PAGE).limit(PER_PAGE + 1).to_a

    Result.new(
      recipes: page_records.first(PER_PAGE),
      page: current_page,
      next_page: page_records.size > PER_PAGE ? current_page + 1 : nil,
      category_options: Recipes::CategoryCatalogQuery.options
    )
  end

  private

  attr_reader :params, :embedder, :ingredient_parser

  def param(name)
    params[name] || params[name.to_s]
  end

  def filter_by_ingredients(relation)
    text = param(:ingredients).to_s
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

    Recipes::IngredientCandidateQuery.new(
      relation:,
      vector: embedder.call(query_names.join("\n")),
      candidate_count: SETTINGS.ingredients_candidate_count,
      max_distance: SETTINGS.ingredients_max_cosine_distance
    ).call
  end

  def query_ingredient_names(text)
    lines = text.split(/[\n,;]+/).filter_map { |line| line.squish.presence }
    parser_result = ingredient_parser.call([ lines ]).first
    Ingredient.filterable_canonical_names_for(lines + parser_result.ingredient_names)
  end

  def page
    value = param(:page).to_i
    value.positive? ? value : DEFAULT_PAGE
  end
end
