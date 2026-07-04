class Avo::Actions::IndexSelectedRecipes < Avo::BaseAction
  self.name = "Index selected recipes"
  self.message = "Queue recipe indexing for the selected recipes?"
  self.confirm_button_label = "Queue indexing"

  def handle(query:, **)
    selection = recipe_selection_from(query)
    return error("Select at least one recipe.").keep_modal_open if selection.fetch(:count).zero?

    IndexRecipeJob.perform_later(selection.fetch(:job_argument))
    succeed "Queued recipe indexing for #{selection.fetch(:label)}."
    reload
  end

  private

  def recipe_selection_from(query)
    recipes = recipe_scope_from(query)
    count = recipes.count
    return { count:, job_argument: [], label: "0 recipes" } if count.zero?

    if whole_recipe_scope?(recipes)
      { count:, job_argument: "all", label: "all recipes" }
    else
      ids = recipes.pluck(:id).uniq
      { count:, job_argument: ids, label: "#{ids.size} #{"recipe".pluralize(ids.size)}" }
    end
  end

  def recipe_scope_from(query)
    return query if query.is_a?(ActiveRecord::Relation)

    Recipe.where(id: Array(query).map(&:id))
  end

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
