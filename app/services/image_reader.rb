require "base64"
require "ipaddr"
require "net/http"
require "socket"
require "uri"

class ImageReader
  class Error < StandardError; end
  class ConfigurationError < Error; end
  class InvalidImageError < Error; end
  class RemoteImageError < Error; end

  ENDPOINT = URI("https://openrouter.ai/api/v1/chat/completions")
  MODELS = [ "google/gemini-2.5-flash-lite", "google/gemini-2.5-flash" ].freeze
  TOOL_NAME = "set_detected_ingredients"
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
  BLOCKED_IP_RANGES = [
    IPAddr.new("0.0.0.0/8"),
    IPAddr.new("224.0.0.0/4"),
    IPAddr.new("::/128"),
    IPAddr.new("ff00::/8")
  ].freeze

  TOOL_DEFINITION = {
    type: "function",
    function: {
      name: TOOL_NAME,
      description: "Returns catalog ingredient names that are visible in the submitted image.",
      parameters: {
        type: "object",
        additionalProperties: false,
        properties: {
          ingredient_names: {
            type: "array",
            description: "Exact catalog ingredient names visible in the image.",
            items: { type: "string" },
            uniqueItems: true
          }
        },
        required: [ "ingredient_names" ]
      }
    }
  }.freeze

  class << self
    def call(file: nil, url: nil, ingredient_names: Ingredient.order(:name).pluck(:name), api_key: SETTINGS.openrouter_api_key)
      raise ConfigurationError, "OpenRouter API key is not configured" if api_key.blank?
      return [] if ingredient_names.empty?

      payload = request_payload(image_url: image_reference(file:, url:), ingredient_names:)
      response = post_openrouter(payload, api_key:)
      parse_ingredient_names(response, ingredient_names)
    end

    private

    def image_reference(file:, url:)
      has_file = file.present?
      has_url = url.to_s.squish.present?

      if has_file && has_url
        raise InvalidImageError, "Choose a photo or paste an image URL, not both."
      elsif has_file
        uploaded_image_data_url(file)
      elsif has_url
        remote_image_url(url)
      else
        raise InvalidImageError, "Choose a photo or paste an image URL."
      end
    end

    def uploaded_image_data_url(file)
      data_url(image_content_type(file.content_type, file.original_filename), read_limited(file))
    end

    def remote_image_url(url)
      uri = parse_remote_uri(url)
      response, _body, final_uri = fetch_remote_image(uri, MAX_REDIRECTS)
      image_content_type(response["Content-Type"], File.basename(final_uri.path))
      final_uri.to_s
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

    def image_content_type(value, filename = nil)
      content_type = value.to_s.split(";").first.to_s.squish.downcase
      content_type = Rack::Mime.mime_type(File.extname(filename.to_s), nil).to_s if content_type.blank? && filename.present?
      normalized = ALLOWED_CONTENT_TYPES[content_type]
      return normalized if normalized

      raise InvalidImageError, "Image must be a JPEG, PNG, WebP, or GIF."
    end

    def parse_remote_uri(value)
      uri = URI.parse(value.to_s.squish)
      raise InvalidImageError, "Image URL must use HTTP or HTTPS." unless uri.is_a?(URI::HTTP) && uri.host.present?
      raise InvalidImageError, "Image URL must not include credentials." if uri.userinfo.present?

      uri
    rescue URI::InvalidURIError
      raise InvalidImageError, "Image URL is not valid."
    end

    def fetch_remote_image(uri, redirects_remaining)
      validate_public_host(uri.host)

      response, body = request_remote_image(uri)
      if response.is_a?(Net::HTTPRedirection)
        raise RemoteImageError, "Image URL redirected too many times." if redirects_remaining.zero?

        location = response["Location"].to_s
        raise RemoteImageError, "Image URL redirected without a location." if location.blank?

        return fetch_remote_image(parse_remote_uri(URI.join(uri, location).to_s), redirects_remaining - 1)
      end

      raise RemoteImageError, "Image URL could not be loaded." unless response.is_a?(Net::HTTPSuccess)

      [ response, body, uri ]
    end

    def request_remote_image(uri)
      body = +""
      response = nil

      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: OPEN_TIMEOUT_SECONDS, read_timeout: READ_TIMEOUT_SECONDS) do |http|
        request = Net::HTTP::Get.new(uri)
        request["User-Agent"] = "PennyLunch ImageReader"

        http.request(request) do |http_response|
          response = http_response
          if http_response.is_a?(Net::HTTPSuccess)
            content_length = http_response["Content-Length"].to_i
            raise InvalidImageError, SIZE_ERROR_MESSAGE if content_length > MAX_IMAGE_BYTES

            http_response.read_body do |chunk|
              body << chunk
              raise InvalidImageError, SIZE_ERROR_MESSAGE if body.bytesize > MAX_IMAGE_BYTES
            end
          end
        end
      end

      [ response, body ]
    rescue Timeout::Error, SystemCallError, SocketError => error
      raise RemoteImageError, "Image URL could not be loaded: #{error.message}"
    end

    def validate_public_host(host)
      addresses = Addrinfo.getaddrinfo(host, nil, nil, :STREAM).map(&:ip_address).uniq
      raise InvalidImageError, "Image URL host could not be reached." if addresses.empty?
      raise InvalidImageError, "Image URL host is not allowed." if addresses.any? { |address| blocked_address?(address) }
    rescue SocketError
      raise InvalidImageError, "Image URL host could not be reached."
    end

    def blocked_address?(address)
      ip = IPAddr.new(address)
      ip.private? || ip.loopback? || ip.link_local? || BLOCKED_IP_RANGES.any? { |range| range.include?(ip) }
    rescue IPAddr::InvalidAddressError
      true
    end

    def request_payload(image_url:, ingredient_names:)
      {
        models: MODELS,
        temperature: 0,
        messages: [
          {
            role: "system",
            content: "Identify food ingredients visible in a household fridge, pantry, counter, grocery, or package photo. Use only the provided catalog names. Include an ingredient only when it is visible or clearly named on packaging. Omit uncertain guesses."
          },
          {
            role: "user",
            content: [
              {
                type: "text",
                text: "Catalog ingredient names:\n#{ingredient_names.join("\n")}\n\nCall #{TOOL_NAME} once with only catalog ingredient names found in the image."
              },
              {
                type: "image_url",
                image_url: { url: image_url }
              }
            ]
          }
        ],
        tools: [ TOOL_DEFINITION ],
        tool_choice: { type: "function", function: { name: TOOL_NAME } }
      }
    end

    def post_openrouter(payload, api_key:)
      response = Net::HTTP.start(ENDPOINT.host, ENDPOINT.port, use_ssl: true, open_timeout: OPEN_TIMEOUT_SECONDS, read_timeout: READ_TIMEOUT_SECONDS) do |http|
        request = Net::HTTP::Post.new(ENDPOINT)
        request["Authorization"] = "Bearer #{api_key}"
        request["Content-Type"] = "application/json"
        request["X-Title"] = "PennyLunch"
        request.body = JSON.generate(payload)
        http.request(request)
      end

      unless response.is_a?(Net::HTTPSuccess)
        body = response.body.to_s.squish
        detail = body.present? ? ": #{body.truncate(300)}" : ""
        raise RemoteImageError, "OpenRouter returned HTTP #{response.code}#{detail}"
      end

      JSON.parse(response.body)
    rescue JSON::ParserError
      raise RemoteImageError, "OpenRouter returned invalid JSON."
    rescue Timeout::Error, SystemCallError, SocketError => error
      raise RemoteImageError, "OpenRouter request failed: #{error.message}"
    end

    def parse_ingredient_names(response, catalog_names)
      tool_call = Array(response.dig("choices", 0, "message", "tool_calls")).find do |call|
        call.dig("function", "name") == TOOL_NAME
      end
      raise RemoteImageError, "OpenRouter response did not include ingredient results." unless tool_call

      arguments = parse_tool_arguments(tool_call.dig("function", "arguments"))
      catalog_lookup = catalog_names.index_by(&:itself)

      Array(arguments["ingredient_names"]).filter_map { catalog_lookup[it.to_s.squish] }.uniq
    end

    def parse_tool_arguments(arguments)
      arguments.is_a?(Hash) ? arguments : JSON.parse(arguments.to_s)
    rescue JSON::ParserError
      raise RemoteImageError, "OpenRouter response included invalid ingredient results."
    end
  end
end
