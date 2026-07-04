class Avo::Actions::SetRecipeSearchStrategy < Avo::BaseAction
  self.name = "Set recipe search strategy"
  self.message = "Set recipe search strategy?"
  self.confirm_button_label = "Update strategy"
  self.standalone = true

  def fields
    field :strategy, as: :select, options: { "Overlap" => "overlap", "Vector" => "vector" }, default: "overlap", required: true
  end

  def handle(fields:, **)
    strategy = fields[:strategy].to_s
    return error("Unknown recipe search strategy.").keep_modal_open unless RecipeIngredientFilterQuery::STRATEGIES.include?(strategy)

    Rails.cache.write(RecipeIngredientFilterQuery::SEARCH_STRATEGY_CACHE_KEY, strategy)
    succeed "Updated recipe search strategy to #{strategy}."
    reload
  end
end
