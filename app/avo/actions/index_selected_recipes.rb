class Avo::Actions::IndexSelectedRecipes < Avo::BaseAction
  self.name = "Index selected recipes"
  self.message = "Queue recipe indexing for the selected recipes?"
  self.confirm_button_label = "Queue indexing"

  def handle(query:, **)
    recipes = Recipe.where(id: query)
    count = recipes.count
    return error("Select at least one recipe.").keep_modal_open if count.zero?

    if query.is_a?(ActiveRecord::Relation) && query.where_clause.empty?
      IndexRecipeJob.perform_later("all")
      succeed "Queued recipe indexing for all recipes."
    else
      ids = recipes.pluck(:id).uniq
      IndexRecipeJob.perform_later(ids)
      succeed "Queued recipe indexing for #{ids.size} #{"recipe".pluralize(ids.size)}."
    end

    reload
  end
end
