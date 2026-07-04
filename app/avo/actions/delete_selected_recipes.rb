class Avo::Actions::DeleteSelectedRecipes < Avo::BaseAction
  self.name = "Delete selected recipes"
  self.message = "Delete the selected recipes?"
  self.confirm_button_label = "Delete recipes"

  def handle(query:, **)
    deleted_count = Recipe.where(id: query).delete_all

    succeed "Deleted #{deleted_count} #{"recipe".pluralize(deleted_count)}."
    reload
  end
end
