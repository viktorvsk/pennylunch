class Avo::Actions::SyncIngredientsFromAliasCatalog < Avo::BaseAction
  self.name = "Sync ingredients from alias catalog"
  self.message = "Sync ingredients from alias catalog?"
  self.confirm_button_label = "Queue sync"
  self.standalone = true

  def handle(**)
    BootstrapIngredients.perform_later
    succeed "Queued ingredient alias catalog sync."
    reload
  end
end
