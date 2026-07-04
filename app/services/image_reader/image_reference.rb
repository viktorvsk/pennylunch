require "base64"
require "ssrf_filter"
require "uri"

class ImageReader
  class ImageReference < Data.define(:url)
    MAX_IMAGE_BYTES = 10 * 1024 * 1024
    MAX_REDIRECTS = 3
    OPEN_TIMEOUT_SECONDS = 5
    READ_TIMEOUT_SECONDS = 30
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
        new(url: data_url(content_type(file.content_type, file.original_filename), read_limited(file)))
      end

      def remote(url)
        raise InvalidImageError, "Image URL must not include credentials." if URI.parse(url).userinfo.present?

        response = fetch_remote_image(url)
        content_type(response["Content-Type"], File.basename(URI(response.uri.to_s).path))
        new(url: response.uri.to_s)
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

      def content_type(value, filename = nil)
        value = value.to_s.split(";").first.to_s.squish.downcase
        value = Rack::Mime.mime_type(File.extname(filename.to_s), nil).to_s if value.blank? && filename.present?
        ALLOWED_CONTENT_TYPES.fetch(value) { raise InvalidImageError, "Image must be a JPEG, PNG, WebP, or GIF." }
      end

      def fetch_remote_image(url)
        SsrfFilter.get(
          url,
          max_redirects: MAX_REDIRECTS,
          headers: { "User-Agent" => "PennyLunch ImageReader" },
          http_options: { open_timeout: OPEN_TIMEOUT_SECONDS, read_timeout: READ_TIMEOUT_SECONDS }
        ) do |response|
          read_success_body(response) if response.is_a?(Net::HTTPSuccess)
        end
      rescue SsrfFilter::InvalidUriScheme
        raise InvalidImageError, "Image URL must use HTTP or HTTPS."
      rescue SsrfFilter::PrivateIPAddress
        raise InvalidImageError, "Image URL host is not allowed."
      rescue SsrfFilter::UnresolvedHostname
        raise InvalidImageError, "Image URL host could not be reached."
      rescue SsrfFilter::TooManyRedirects
        raise RemoteImageError, "Image URL redirected too many times."
      rescue SsrfFilter::Error => error
        raise RemoteImageError, "Image URL could not be loaded: #{error.message}"
      rescue Timeout::Error, SystemCallError, SocketError => error
        raise RemoteImageError, "Image URL could not be loaded: #{error.message}"
      end

      def read_success_body(response)
        content_length = response["Content-Length"].to_i
        raise InvalidImageError, SIZE_ERROR_MESSAGE if content_length > MAX_IMAGE_BYTES

        bytes_read = 0
        response.read_body do |chunk|
          bytes_read += chunk.bytesize
          raise InvalidImageError, SIZE_ERROR_MESSAGE if bytes_read > MAX_IMAGE_BYTES
        end
      end
    end
  end
end
