class Avo::Actions::DeleteSelectedIngredients < Avo::BaseAction
  self.name = "Delete selected ingredients"
  self.message = "Delete the selected ingredients?"
  self.confirm_button_label = "Delete ingredients"

  def handle(query:, **)
    deleted_count = query.delete_all

    succeed "Deleted #{deleted_count} #{"ingredient".pluralize(deleted_count)}."
    reload
  end
end
