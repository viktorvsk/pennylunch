class Avo::Actions::DeleteSelectedIngredients < Avo::BaseAction
  self.name = "Delete selected ingredients"
  self.message = "Delete the selected ingredients?"
  self.confirm_button_label = "Delete ingredients"

  def handle(query:, **)
    ingredients = query.is_a?(ActiveRecord::Relation) ? query : Ingredient.where(id: query.map(&:id))
    deleted_count = ingredients.delete_all

    succeed "Deleted #{deleted_count} #{"ingredient".pluralize(deleted_count)}."
    reload
  end
end
