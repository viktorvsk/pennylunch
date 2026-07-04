module Maintenance
  class DeleteRecipesTask < MaintenanceTasks::Task
    no_collection

    def process
      Recipe.delete_all
    end
  end
end
