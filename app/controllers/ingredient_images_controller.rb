class IngredientImagesController < ApplicationController
  def create
    image = params.require(:image).permit(:file, :url)
    render json: { ingredients: ImageReader.call(file: image[:file], url: image[:url]) }
  rescue ImageReader::InvalidImageError => error
    render json: { error: error.message }, status: :unprocessable_content
  rescue ImageReader::Error => error
    Rails.logger.warn("ImageReader failed: #{error.class}: #{error.message}")
    render json: { error: "Pen could not read that image right now." }, status: :bad_gateway
  end
end
