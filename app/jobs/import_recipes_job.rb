class ImportRecipesJob < ApplicationJob
  def perform(url)
    RecipeImport.call(url:)
  end
end
