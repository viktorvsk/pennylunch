require "net/http"
require "uri"

class ImageReader
  # Calls OpenRouter's chat-completions API with a forced ingredient-detection
  # tool call.
  #
  # Returns `Array<String>` after parsing the tool arguments and filtering them
  # back to exact catalog names supplied in the prompt. Raises `RemoteImageError`
  # for HTTP failures, transport failures, invalid JSON, or missing tool results.
  class OpenRouterClient < Data.define(:api_key, :catalog_names, :image_url)
    ENDPOINT = URI("https://openrouter.ai/api/v1/chat/completions")
    MODELS = [ "google/gemini-2.5-flash-lite", "google/gemini-2.5-flash" ].freeze
    TOOL_NAME = "set_detected_ingredients"
    HTTP_OPTIONS = { use_ssl: true, open_timeout: 5, read_timeout: 30 }.freeze
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

    def call
      parse_ingredient_names(post(request_payload))
    end

    private

    def request_payload
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
                text: "Catalog ingredient names:\n#{catalog_names.join("\n")}\n\nCall #{TOOL_NAME} once with only catalog ingredient names found in the image."
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

    def post(payload)
      response = Net::HTTP.start(ENDPOINT.host, ENDPOINT.port, **HTTP_OPTIONS) do |http|
        request = Net::HTTP::Post.new(ENDPOINT)
        request["Authorization"] = "Bearer #{api_key}"
        request["Content-Type"] = "application/json"
        request["X-Title"] = "PennyLunch"
        request.body = JSON.generate(payload)
        http.request(request)
      end

      raise_http_error(response) unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body)
    rescue JSON::ParserError
      raise RemoteImageError, "OpenRouter returned invalid JSON."
    rescue Timeout::Error, SystemCallError, SocketError => error
      raise RemoteImageError, "OpenRouter request failed: #{error.message}"
    end

    def raise_http_error(response)
      body = response.body.to_s.squish
      detail = body.present? ? ": #{body.truncate(300)}" : ""
      raise RemoteImageError, "OpenRouter returned HTTP #{response.code}#{detail}"
    end

    def parse_ingredient_names(response)
      tool_call = response.fetch("choices").first.fetch("message").fetch("tool_calls").find do |call|
        call.fetch("function").fetch("name") == TOOL_NAME
      end
      raise RemoteImageError, "OpenRouter response did not include ingredient results." unless tool_call

      arguments = JSON.parse(tool_call.fetch("function").fetch("arguments"))
      catalog_lookup = catalog_names.index_by(&:itself)
      Array(arguments.fetch("ingredient_names")).filter_map { |name| catalog_lookup[name.to_s.squish] }.uniq
    rescue KeyError, NoMethodError, TypeError
      raise RemoteImageError, "OpenRouter response did not include ingredient results."
    rescue JSON::ParserError
      raise RemoteImageError, "OpenRouter response included invalid ingredient results."
    end
  end
end
