class IngredientImagesController < ApplicationController
  def create
    render json: { ingredients: ImageReader.call(file: image_params[:file], url: image_params[:url]) }
  rescue ImageReader::InvalidImageError => error
    render json: { error: error.message }, status: :unprocessable_content
  rescue ImageReader::Error => error
    Rails.logger.warn("ImageReader failed: #{error.class}: #{error.message}")
    render json: { error: "Pen could not read that image right now." }, status: :bad_gateway
  end

  private

  def image_params
    params.fetch(:image, ActionController::Parameters.new).permit(:file, :url)
  end
end
