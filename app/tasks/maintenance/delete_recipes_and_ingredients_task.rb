module Maintenance
  class DeleteRecipesAndIngredientsTask < MaintenanceTasks::Task
    no_collection

    def process
      Recipe.transaction do
        Recipe.delete_all
        Ingredient.delete_all
      end
    end
  end
end
