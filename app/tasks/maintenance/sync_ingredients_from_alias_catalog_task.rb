module Maintenance
  class SyncIngredientsFromAliasCatalogTask < MaintenanceTasks::Task
    no_collection

    def process
      Ingredients::SyncFromAliasCatalog.call
    end
  end
end
