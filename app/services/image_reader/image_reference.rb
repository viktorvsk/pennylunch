require "base64"
require "marcel"
require "ssrf_filter"
require "uri"

class ImageReader
  # Normalizes a submitted image into a URL string that OpenRouter can consume.
  #
  # Uploaded files become validated base64 data URLs. Remote URLs are fetched
  # through `SsrfFilter` for scheme, redirect, private-network, content type, and
  # size checks, then returned as their final URL.
  #
  # Returns `ImageReader::ImageReference` with a `url` attribute. Raises
  # `InvalidImageError` for user-correctable image input problems and
  # `RemoteImageError` when a remote URL cannot be loaded safely.
  class ImageReference < Data.define(:url)
    MAX_IMAGE_BYTES = 10 * 1024 * 1024
    SIZE_ERROR_MESSAGE = "Image must be smaller than 10 MB."
    FETCH_OPTIONS = {
      max_redirects: 3,
      headers: { "User-Agent" => "PennyLunch ImageReader" },
      http_options: { open_timeout: 5, read_timeout: 30 }
    }.freeze
    ALLOWED_CONTENT_TYPES = {
      "image/jpg" => "image/jpeg",
      "image/jpeg" => "image/jpeg",
      "image/png" => "image/png",
      "image/webp" => "image/webp",
      "image/gif" => "image/gif"
    }.freeze
    GENERIC_CONTENT_TYPES = [ "", "application/octet-stream", "binary/octet-stream" ].freeze
    RemoteImage = Data.define(:url, :content_type, :body)

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
        raise InvalidImageError, "Image URL must not include credentials." if URI.parse(url).userinfo.present?

        image = fetch_remote_image(url)
        content_type(image.content_type, File.basename(URI(image.url).path), image.body)
        new(url: image.url)
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
        raise InvalidImageError, "Image must be a JPEG, PNG, WebP, or GIF." if sniffed_type.present? && GENERIC_CONTENT_TYPES.exclude?(sniffed_type)

        declared_type = normalized_content_type(value)
        return ALLOWED_CONTENT_TYPES.fetch(declared_type) if ALLOWED_CONTENT_TYPES.key?(declared_type)

        extension_type = normalized_content_type(Rack::Mime.mime_type(File.extname(filename.to_s), nil)) if filename.present? && GENERIC_CONTENT_TYPES.include?(declared_type)
        ALLOWED_CONTENT_TYPES.fetch(extension_type) { raise InvalidImageError, "Image must be a JPEG, PNG, WebP, or GIF." }
      end

      def fetch_remote_image(url)
        body = nil
        response = SsrfFilter.get(
          url,
          **FETCH_OPTIONS
        ) do |response|
          body = read_success_body(response) if response.is_a?(Net::HTTPSuccess)
        end

        raise RemoteImageError, "Image URL returned HTTP #{response.code}." unless response.is_a?(Net::HTTPSuccess)

        RemoteImage.new(url: response.uri.to_s, content_type: response["Content-Type"], body:)
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
        body = +"".b
        response.read_body do |chunk|
          bytes_read += chunk.bytesize
          raise InvalidImageError, SIZE_ERROR_MESSAGE if bytes_read > MAX_IMAGE_BYTES

          body << chunk
        end
        raise InvalidImageError, "Image cannot be empty." if body.bytesize.zero?

        body
      end

      def normalized_content_type(value)
        value.to_s.split(";").first.to_s.squish.downcase
      end
    end
  end
end
