require "rails_helper"

RSpec.describe "Ingredient images", type: :request do
  describe "POST /ingredient_image" do
    it "returns canonical ingredients detected from the submitted image URL" do
      allow(ImageReader).to receive(:call).and_return([ "tomato", "pasta" ])

      post ingredient_image_path, params: { image: { url: "https://example.com/pantry.jpg" } }, as: :json

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to eq("ingredients" => [ "tomato", "pasta" ])
      expect(ImageReader).to have_received(:call).with(file: nil, url: "https://example.com/pantry.jpg")
    end

    it "returns a validation error when image input is invalid" do
      allow(ImageReader).to receive(:call).and_raise(ImageReader::InvalidImageError, "Choose a photo or paste an image URL.")

      post ingredient_image_path, params: { image: { url: "" } }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(JSON.parse(response.body)).to eq("error" => "Choose a photo or paste an image URL.")
    end
  end
end
