class Avo::Actions::BootstrapIngredients < Avo::BaseAction
  self.name = "Bootstrap ingredients"
  self.message = "Bootstrap ingredients from alias catalog?"
  self.confirm_button_label = "Queue bootstrap"
  self.standalone = true

  def handle(**)
    ::BootstrapIngredients.perform_later
    succeed "Queued ingredient catalog bootstrap."
    reload
  end
end
