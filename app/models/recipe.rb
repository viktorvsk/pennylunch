require "uri"

class Recipe < ApplicationRecord
  SOURCE_FIELDS = %w[title cook_time prep_time ingredients ratings cuisine category author image].freeze
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
      source_categories = where.not(category_normalized: "").pluck(:category_normalized, :category).group_by(&:first)

      source_categories.keys.sort.to_h do |normalized|
        label = source_categories.fetch(normalized, [])
          .filter_map { |(_, category)| category.to_s.squish.presence }
          .min_by { |category| [ category == normalize_category(category) ? 1 : 0, category.downcase ] }

        [ normalized, label || normalized ]
      end
    end

    def slug_for(attributes)
      [ attributes.fetch(:title), attributes.fetch(:category), attributes.fetch(:author), "#{attributes.fetch(:total_time)}-minutes" ].filter_map do |part|
        part.to_s.parameterize(preserve_case: true).presence
      end.join("-")
    end
  end

  def to_param
    [ self.class.slug_for(title:, category:, author:, total_time:), id ].compact.join("-")
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
    self.ingredient_names = Array(ingredient_names).filter_map { |name| name.to_s.squish.downcase.presence }.uniq
    self.category_normalized = self.class.normalize_category(category)
    self.total_time = prep_time.to_i + cook_time.to_i
  end
end
