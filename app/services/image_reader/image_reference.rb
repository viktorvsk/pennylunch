require "base64"
require "marcel"
require "uri"

class ImageReader
  # Normalizes a submitted image into a URL string that OpenRouter can consume.
  #
  # Uploaded files become validated base64 data URLs. Remote URLs are validated
  # as HTTP(S) URLs and passed through for OpenRouter to fetch.
  #
  # Returns `ImageReader::ImageReference` with a `url` attribute. Raises
  # `InvalidImageError` for user-correctable image input problems.
  class ImageReference < Data.define(:url)
    MAX_IMAGE_BYTES = 10 * 1024 * 1024
    SIZE_ERROR_MESSAGE = "Image must be smaller than 10 MB."
    ALLOWED_CONTENT_TYPES = {
      "image/jpg" => "image/jpeg",
      "image/jpeg" => "image/jpeg",
      "image/png" => "image/png",
      "image/webp" => "image/webp",
      "image/gif" => "image/gif"
    }.freeze

    class << self
      def build(file:, url:)
        url = url.to_s.squish
        raise InvalidImageError, "Choose a photo or paste an image URL, not both." if file.present? && url.present?
        return uploaded(file) if file.present?
        return remote(url) if url.present?

        raise InvalidImageError, "Choose a photo or paste an image URL."
      end

      private

      def uploaded(file)
        body = read_limited(file)
        new(url: data_url(content_type(file.content_type, file.original_filename, body), body))
      end

      def remote(url)
        uri = URI.parse(url)
        raise InvalidImageError, "Image URL must not include credentials." if uri.userinfo.present?

        validate_remote_uri(uri)
        new(url: uri.to_s)
      rescue URI::InvalidURIError
        raise InvalidImageError, "Image URL is not valid."
      end

      def data_url(content_type, body)
        raise InvalidImageError, "Image cannot be empty." if body.bytesize.zero?

        "data:#{content_type};base64,#{Base64.strict_encode64(body)}"
      end

      def read_limited(io)
        body = io.read(MAX_IMAGE_BYTES + 1).to_s
        raise InvalidImageError, SIZE_ERROR_MESSAGE if body.bytesize > MAX_IMAGE_BYTES

        body
      end

      def content_type(value, filename = nil, body = nil)
        sniffed_type = normalized_content_type(Marcel::MimeType.for(body)) if body&.bytesize&.positive?
        return ALLOWED_CONTENT_TYPES.fetch(sniffed_type) if ALLOWED_CONTENT_TYPES.key?(sniffed_type)
        raise InvalidImageError, "Image must be a JPEG, PNG, WebP, or GIF." if sniffed_type.present? && !generic_content_type?(sniffed_type)

        declared_type = normalized_content_type(value)
        return ALLOWED_CONTENT_TYPES.fetch(declared_type) if ALLOWED_CONTENT_TYPES.key?(declared_type)

        extension_type = normalized_content_type(Rack::Mime.mime_type(File.extname(filename.to_s), nil)) if filename.present? && generic_content_type?(declared_type)
        ALLOWED_CONTENT_TYPES.fetch(extension_type) { raise InvalidImageError, "Image must be a JPEG, PNG, WebP, or GIF." }
      end

      def validate_remote_uri(uri)
        raise InvalidImageError, "Image URL must use HTTP or HTTPS." unless %w[http https].include?(uri.scheme)
        raise InvalidImageError, "Image URL is not valid." if uri.hostname.blank?

        extension = File.extname(uri.path)
        content_type(nil, File.basename(uri.path)) if extension.present?
      end

      def normalized_content_type(value)
        value.to_s.split(";").first.to_s.squish.downcase
      end

      def generic_content_type?(value)
        value.blank? || value.in?([ "application/octet-stream", "binary/octet-stream" ])
      end
    end
  end
end
