class ImportRecipesJob < ApplicationJob
  queue_as :default

  class InvalidUrlError < StandardError; end

  def perform(url = RecipeImport::DEFAULT_URL)
    normalized_url = url.to_s.squish
    raise InvalidUrlError, "recipe import URL can't be blank" if normalized_url.blank?

    RecipeImport.call(url: normalized_url)
  end
end
