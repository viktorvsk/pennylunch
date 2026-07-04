module Maintenance
  class BootstrapIngredientsFromRecipeNamesTask < MaintenanceTasks::Task
    no_collection

    def process
      Ingredients::SyncFromAliasCatalog.call
    end
  end
end
