module Maintenance
  class ImportRecipesTask < MaintenanceTasks::Task
    no_collection

    def process
      Recipes::Import.call
    end
  end
end
