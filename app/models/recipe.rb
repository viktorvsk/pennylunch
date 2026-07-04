class Recipe < ApplicationRecord
  has_many :recipe_ingredients, dependent: :delete_all
  has_many :resolved_ingredients, through: :recipe_ingredients, source: :ingredient
  has_neighbors :ingredients_vector

  before_validation :derive_fields

  validates :title, :cook_time, :prep_time, :ingredients, :ratings, :image, :total_time, :source_position, presence: true
  validates :cook_time, :prep_time, :total_time, numericality: { greater_than_or_equal_to: 0 }
  validates :source_position, uniqueness: true

  class << self
    def normalize_category(value)
      value.to_s.strip.downcase
    end

    def category_slug_for(value)
      normalize_category(value).parameterize
    end

    def category_labels
      where.not(category_normalized: "")
        .pluck(:category_normalized, :category)
        .group_by(&:first)
        .transform_values { |pairs| pairs.map(&:second).filter_map { it.to_s.squish.presence }.min_by { [ it == normalize_category(it) ? 1 : 0, it.downcase ] } }
        .sort
        .to_h
    end

    def id_from_param(value)
      value.to_s.rpartition("-").last
    end
  end

  def to_param
    [ title, category, author, "#{total_time}-minutes", id ].filter_map { it.to_s.parameterize(preserve_case: true).presence }.join("-")
  end

  def display_image_url
    uri = URI.parse(image.to_s)
    return image unless uri.host == "imagesvc.meredithcorp.io"

    URI.decode_www_form(uri.query.to_s).to_h.fetch("url", image)
  rescue URI::InvalidURIError
    image
  end

  private

  def derive_fields
    self.ingredient_names = Array(ingredient_names).filter_map { Ingredient.normalize_lookup_key(it) }.uniq
    self.category_normalized = self.class.normalize_category(category)
    self.total_time = prep_time.to_i + cook_time.to_i
  end
end
