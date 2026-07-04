# Reads visible catalog ingredients from a user-provided image via OpenRouter.
#
# Accepts either an uploaded file or a remote URL, validates and normalizes the
# image through `ImageReference`, and asks `OpenRouterClient` to return exact
# catalog names only.
#
# Returns `Array<String>` of catalog ingredient names. Raises
# `ConfigurationError`, `InvalidImageError`, or `RemoteImageError` for the
# corresponding setup, input, and remote-service failures.
class ImageReader
  class Error < StandardError; end
  class ConfigurationError < Error; end
  class InvalidImageError < Error; end
  class RemoteImageError < Error; end

  class << self
    def call(file: nil, url: nil, **options)
      options.assert_valid_keys(:ingredient_names, :api_key)
      ingredient_names = options.fetch(:ingredient_names) { Ingredient.order(:name).pluck(:name) }
      api_key = options.fetch(:api_key) { SETTINGS.openrouter_api_key }

      raise ConfigurationError, "OpenRouter API key is not configured" if api_key.blank?
      return [] if ingredient_names.empty?

      image = ImageReference.build(file:, url:)
      OpenRouterClient.new(api_key:, catalog_names: ingredient_names, image_url: image.url).call
    end
  end
end
