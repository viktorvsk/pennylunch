class Avo::Actions::IndexSelectedRecipes < Avo::BaseAction
  self.name = "Index selected recipes"
  self.message = "Queue recipe indexing for the selected recipes?"
  self.confirm_button_label = "Queue indexing"

  def handle(query:, **)
    recipes = query.is_a?(ActiveRecord::Relation) ? query : Recipe.where(id: query.map(&:id))
    count = recipes.count
    return error("Select at least one recipe.").keep_modal_open if count.zero?

    if whole_recipe_scope?(recipes)
      IndexRecipeJob.perform_later("all")
      succeed "Queued recipe indexing for all recipes."
    else
      ids = recipes.pluck(:id).uniq
      IndexRecipeJob.perform_later(ids)
      succeed "Queued recipe indexing for #{ids.size} #{"recipe".pluralize(ids.size)}."
    end

    reload
  end

  private

  def whole_recipe_scope?(recipes)
    recipes.is_a?(ActiveRecord::Relation) &&
      recipes.where_clause.empty? &&
      recipes.limit_value.nil? &&
      recipes.offset_value.nil? &&
      recipes.group_values.empty? &&
      recipes.having_clause.empty? &&
      !recipes.distinct_value
  end
end
