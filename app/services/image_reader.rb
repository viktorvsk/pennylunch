require "base64"
require "marcel"
require "uri"

# Reads visible catalog ingredients from a user-provided image via OpenRouter.
#
# Accepts either an uploaded file or a remote URL, validates and normalizes it,
# and asks `OpenRouterClient` to return exact catalog names only.
#
# Returns `Array<String>` of catalog ingredient names. Raises
# `ConfigurationError`, `InvalidImageError`, or `RemoteImageError` for the
# corresponding setup, input, and remote-service failures.
class ImageReader
  MAX_IMAGE_BYTES = 10 * 1024 * 1024
  ALLOWED_CONTENT_TYPES = {
    "image/jpg" => "image/jpeg",
    "image/jpeg" => "image/jpeg",
    "image/png" => "image/png",
    "image/webp" => "image/webp",
    "image/gif" => "image/gif"
  }.freeze
  GENERIC_CONTENT_TYPES = [ "", "application/octet-stream", "binary/octet-stream" ].freeze

  class Error < StandardError; end
  class ConfigurationError < Error; end
  class InvalidImageError < Error; end
  class RemoteImageError < Error; end

  class << self
    def call(file: nil, url: nil, ingredient_names: nil)
      api_key = SETTINGS.openrouter_api_key
      ingredient_names ||= Ingredient.catalog_names
      raise ConfigurationError, "OpenRouter API key is not configured" if api_key.blank?
      return [] if ingredient_names.empty?

      image_url = normalized_image_url(file:, url:)
      OpenRouterClient.new(api_key:, catalog_names: ingredient_names, image_url:).call
    end

    private

    def normalized_image_url(file:, url:)
      url = url.to_s.squish
      raise InvalidImageError, "Choose a photo or paste an image URL, not both." if file.present? && url.present?
      return uploaded_image_url(file) if file.present?
      return remote_image_url(url) if url.present?

      raise InvalidImageError, "Choose a photo or paste an image URL."
    end

    def uploaded_image_url(file)
      body = file.read(MAX_IMAGE_BYTES + 1).to_s
      raise InvalidImageError, "Image must be smaller than 10 MB." if body.bytesize > MAX_IMAGE_BYTES
      raise InvalidImageError, "Image cannot be empty." if body.bytesize.zero?

      "data:#{content_type(file.content_type, file.original_filename, body)};base64,#{Base64.strict_encode64(body)}"
    end

    def remote_image_url(url)
      uri = URI.parse(url)
      raise InvalidImageError, "Image URL must not include credentials." if uri.userinfo.present?
      raise InvalidImageError, "Image URL must use HTTP or HTTPS." unless %w[http https].include?(uri.scheme)
      raise InvalidImageError, "Image URL is not valid." if uri.hostname.blank?

      content_type(nil, File.basename(uri.path)) if File.extname(uri.path).present?
      uri.to_s
    rescue URI::InvalidURIError
      raise InvalidImageError, "Image URL is not valid."
    end

    def content_type(value, filename = nil, body = nil)
      sniffed_type = normalized_content_type(Marcel::MimeType.for(body)) if body&.bytesize&.positive?
      return ALLOWED_CONTENT_TYPES.fetch(sniffed_type) if ALLOWED_CONTENT_TYPES.key?(sniffed_type)
      raise InvalidImageError, "Image must be a JPEG, PNG, WebP, or GIF." if sniffed_type.present? && !GENERIC_CONTENT_TYPES.include?(sniffed_type)

      declared_type = normalized_content_type(value)
      return ALLOWED_CONTENT_TYPES.fetch(declared_type) if ALLOWED_CONTENT_TYPES.key?(declared_type)

      extension_type = normalized_content_type(Rack::Mime.mime_type(File.extname(filename.to_s), nil)) if filename.present? && GENERIC_CONTENT_TYPES.include?(declared_type)
      ALLOWED_CONTENT_TYPES.fetch(extension_type) { raise InvalidImageError, "Image must be a JPEG, PNG, WebP, or GIF." }
    end

    def normalized_content_type(value)
      value.to_s.split(";").first.to_s.squish.downcase
    end
  end
end
