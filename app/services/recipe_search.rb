class RecipeSearch
  DEFAULT_CANDIDATE_COUNT = 250

  def self.call(relation:, ingredients:)
    new(relation:, ingredients:).call
  end

  def initialize(relation:, ingredients:)
    @relation = relation
    @ingredients = ingredients.to_s
  end

  def call
    return relation if ingredients.blank?

    case SETTINGS.ingredients_filter_strategy.to_s
    when "naive_vector_search"
      filter_by_ingredient_vector
    else
      raise ArgumentError, "unsupported ingredients filter strategy: #{SETTINGS.ingredients_filter_strategy}"
    end
  end

  private

  attr_reader :relation, :ingredients

  def filter_by_ingredient_vector
    lines = ingredients.split(/[\n,;]+/).filter_map { |line| line.squish.presence }
    parser_result = IngredientParser.call([ lines ]).first
    query_names = Ingredient.filterable_canonical_names_for(lines + parser_result.ingredient_names)

    return relation if query_names.empty?

    vector = LocalEmbedding.call(query_names.join("\n"))
    count = SETTINGS.ingredients_candidate_count.to_i.positive? ? SETTINGS.ingredients_candidate_count.to_i : DEFAULT_CANDIDATE_COUNT
    threshold = SETTINGS.ingredients_max_cosine_distance.to_f.positive? ? SETTINGS.ingredients_max_cosine_distance.to_f : nil
    ids = relation
      .where.not(ingredients_vector: nil)
      .nearest_neighbors(:ingredients_vector, vector, distance: "cosine", threshold:)
      .limit(count)
      .pluck(:id)

    relation.where(id: ids)
  end
end
