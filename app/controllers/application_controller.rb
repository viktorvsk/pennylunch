class ApplicationController < ActionController::Base
  INGREDIENT_BASKET_COOKIE = "pennylunch.ingredients".freeze
  MAX_INGREDIENT_BASKET_ITEMS = 100

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  protected

  def ingredients_basket
    payload = JSON.parse(cookies[INGREDIENT_BASKET_COOKIE].to_s)
    return unless payload.is_a?(Hash)
    return unless payload["enabled"]

    Array(payload["selected"]).map(&:squish).compact_blank.first(MAX_INGREDIENT_BASKET_ITEMS)
  rescue JSON::ParserError
    nil
  end
end
