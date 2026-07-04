require "rails_helper"
require "webmock/rspec"

WebMock.disable_net_connect!(allow_localhost: true)

RSpec.describe ImageReader do
  class FakeImageUpload
    attr_reader :content_type, :original_filename

    def initialize(body:, content_type:, original_filename:)
      @body = body
      @content_type = content_type
      @original_filename = original_filename
      @io = StringIO.new(body)
    end

    def read(length = nil)
      length ? @io.read(length) : @io.read
    end

    def rewind
      @io.rewind
    end
  end

  let(:uploaded_file) { FakeImageUpload.new(body: "png-bytes", content_type: "image/png", original_filename: "basket.png") }
  let(:api_key) { "openrouter-test-key" }
  let(:request_body) { JSON.parse(WebMock::RequestRegistry.instance.requested_signatures.hash.keys.last.body) }

  before do
    create(:ingredient, name: "pasta")
    create(:ingredient, name: "tomato")
  end

  it "sends a normalized image and ingredient catalog through a forced OpenRouter tool call" do
    stub_request(:post, "https://openrouter.ai/api/v1/chat/completions")
      .with(headers: { "Authorization" => "Bearer #{api_key}" })
      .to_return(
        status: 200,
        body: {
          "choices" => [
            {
              "message" => {
                "tool_calls" => [
                  {
                    "function" => {
                      "name" => "set_detected_ingredients",
                      "arguments" => {
                        "ingredient_names" => [ "tomato", "unknown", "pasta", "tomato" ]
                      }.to_json
                    }
                  }
                ]
              }
            }
          ]
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = described_class.call(file: uploaded_file, ingredient_names: Ingredient.order(:name).pluck(:name), api_key:)

    aggregate_failures do
      expect(result).to eq([ "tomato", "pasta" ])
      expect(request_body.fetch("models")).to eq([ "google/gemini-2.5-flash-lite", "google/gemini-2.5-flash" ])
      expect(request_body.fetch("temperature")).to eq(0)
      expect(request_body.fetch("tool_choice")).to eq({
        "type" => "function",
        "function" => { "name" => "set_detected_ingredients" }
      })
      expect(request_body.fetch("tools").first.fetch("function").fetch("parameters").fetch("properties").fetch("ingredient_names").fetch("items")).to eq({ "type" => "string" })
      expect(request_body.fetch("messages").last.fetch("content").last.fetch("image_url").fetch("url")).to start_with("data:image/png;base64,")
    end
  end

  it "validates and passes a direct image URL before calling OpenRouter" do
    image_url = "https://static.toiimg.com/thumb/imgsize-23456,msid-67569873,width-600,resizemode-4/67569873.jpg"
    allow(Resolv).to receive(:getaddresses).with("static.toiimg.com").and_return([ "93.184.216.34" ])
    stub_request(:get, image_url)
      .to_return(status: 200, body: "jpeg-bytes", headers: { "Content-Type" => "image/jpeg" })
    stub_request(:post, "https://openrouter.ai/api/v1/chat/completions")
      .to_return(
        status: 200,
        body: {
          "choices" => [
            {
              "message" => {
                "tool_calls" => [
                  {
                    "function" => {
                      "name" => "set_detected_ingredients",
                      "arguments" => { "ingredient_names" => [ "tomato" ] }.to_json
                    }
                  }
                ]
              }
            }
          ]
        }.to_json
      )

    result = described_class.call(url: image_url, ingredient_names: [ "tomato" ], api_key:)

    expect(result).to eq([ "tomato" ])
    expect(request_body.fetch("messages").last.fetch("content").last.fetch("image_url").fetch("url")).to eq(image_url)
  end

  it "requires an API key" do
    expect {
      described_class.call(file: uploaded_file, ingredient_names: [ "tomato" ], api_key: nil)
    }.to raise_error(ImageReader::ConfigurationError, "OpenRouter API key is not configured")
  end

  it "rejects empty image payloads" do
    empty_file = FakeImageUpload.new(body: "", content_type: "image/png", original_filename: "empty.png")

    expect {
      described_class.call(file: empty_file, ingredient_names: [ "tomato" ], api_key:)
    }.to raise_error(ImageReader::InvalidImageError, "Image cannot be empty.")
  end

  it "wraps remote image network failures in RemoteImageError" do
    stub_request(:get, "https://example.com/pantry.jpg").to_timeout

    expect {
      described_class.call(url: "https://example.com/pantry.jpg", ingredient_names: [ "tomato" ], api_key:)
    }.to raise_error(ImageReader::RemoteImageError, /could not be loaded/)
  end

  it "wraps OpenRouter network failures in RemoteImageError" do
    stub_request(:post, "https://openrouter.ai/api/v1/chat/completions").to_timeout

    expect {
      described_class.call(file: uploaded_file, ingredient_names: [ "tomato" ], api_key:)
    }.to raise_error(ImageReader::RemoteImageError, /request failed/)
  end
end
