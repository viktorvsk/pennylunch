class ImportRecipesJob < ApplicationJob
  def perform(url = RecipeImport::DEFAULT_URL)
    RecipeImport.call(url:)
  end
end
