module Maintenance
  class ReloadIngredientsFromAliasCatalogTask < MaintenanceTasks::Task
    no_collection

    def process
      Ingredients::SyncFromAliasCatalog.call(recipe_coverage: :skip)
    end
  end
end
