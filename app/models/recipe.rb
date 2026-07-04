require "digest"
require "uri"

class Recipe < ApplicationRecord
  SOURCE_FIELDS = %w[title cook_time prep_time ingredients ratings cuisine category author image].freeze
  has_neighbors :ingredients_vector

  before_validation :derive_fields

  validates :title, :cook_time, :prep_time, :ingredients, :ratings, :image, :total_time,
    :source_key, :source_position, :slug, presence: true
  validates :cook_time, :prep_time, :total_time, numericality: { greater_than_or_equal_to: 0 }
  validates :source_key, :source_position, :slug, uniqueness: true
  validate :ingredient_names_are_unique
  validate :ingredient_parse_data_matches_ingredients

  def self.source_key_for(title:, category:, author:)
    Digest::SHA256.hexdigest(JSON.generate([
      title.to_s.strip.downcase,
      category.to_s.strip.downcase,
      author.to_s.strip.downcase
    ]))
  end

  def self.display_image_url_for(url)
    uri = URI.parse(url.to_s)
    return url unless uri.host == "imagesvc.meredithcorp.io"

    URI.decode_www_form(uri.query.to_s).to_h.fetch("url", url)
  rescue URI::InvalidURIError
    url
  end

  def self.normalize_category(value)
    value.to_s.strip.downcase
  end

  def self.category_slug_for(value)
    normalize_category(value).parameterize
  end

  def self.slug_for(attributes)
    [ attributes.fetch(:title), attributes.fetch(:category), attributes.fetch(:author), "#{attributes.fetch(:total_time)}-minutes" ].filter_map do |part|
      part.to_s.parameterize(preserve_case: true).presence
    end.join("-")
  end

  def display_image_url
    self.class.display_image_url_for(image)
  end

  def total_time_known?
    total_time.to_i.positive?
  end

  private

  def derive_fields
    self.ingredient_names = Array(ingredient_names).filter_map { |name| name.to_s.squish.downcase.presence }.uniq
    self.category_normalized = self.class.normalize_category(category)
    self.total_time = prep_time.to_i + cook_time.to_i
    self.source_key = self.class.source_key_for(title:, category:, author:) if title && category && author
    self.slug = self.class.slug_for(title:, category:, author:, total_time:) if title && author && total_time
  end

  def ingredient_names_are_unique
    names = Array(ingredient_names)
    errors.add(:ingredient_names, "must be unique") if names.uniq.size != names.size
  end

  def ingredient_parse_data_matches_ingredients
    return if ingredient_parse_data.blank?

    errors.add(:ingredient_parse_data, "must match ingredients") unless ingredient_parse_data.is_a?(Array) && ingredient_parse_data.size == ingredients.size
  end
end
