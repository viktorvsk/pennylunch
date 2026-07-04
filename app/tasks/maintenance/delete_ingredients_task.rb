module Maintenance
  class DeleteIngredientsTask < MaintenanceTasks::Task
    no_collection

    def process
      Ingredient.delete_all
    end
  end
end
