class Ingredient < ActiveRecord::Base
  CATALOG_NAMES_CACHE_KEY = "ingredients/catalog_names/v1"
  CATALOG_METADATA_CACHE_KEY = "ingredients/catalog_metadata/v3"
  FILTERABLE_LOOKUP_CACHE_KEY = "ingredients/filterable_lookup_map"

  has_many :recipe_ingredients, dependent: :delete_all

  normalizes :name, with: ->(name) { name.to_s.squish.downcase.presence }
  normalizes :aliases, with: ->(aliases) { aliases.is_a?(Array) ? aliases.filter_map { it.to_s.squish.downcase.presence }.uniq : aliases }

  validates :name, presence: true, uniqueness: true
  validates :name, format: { without: /,/, message: "must not contain commas" }
  validate :aliases_must_be_valid
  validate :aliases_must_be_unique

  after_commit :clear_cache

  class << self
    def catalog_names
      Rails.cache.fetch(CATALOG_NAMES_CACHE_KEY) do
        order(:name).pluck(:name)
      end
    end

    def filterable_matches(text)
      names = Array(text).filter_map { it.to_s.squish.presence }.uniq
      return [] if names.empty?

      by_name = where(optional: false, name: names).index_by(&:name)
      names.filter_map { by_name[it] }
    end

    def filterable_lookup
      Rails.cache.fetch(FILTERABLE_LOOKUP_CACHE_KEY) do
        where(optional: false).pluck(:name, :aliases).each_with_object({}) do |(name, aliases), mapping|
          [ name, *aliases ].each do |value|
            mapping[value] = name
          end
        end
      end
    end

    def catalog_metadata
      Rails.cache.fetch(CATALOG_METADATA_CACHE_KEY) do
        pluck(:name, :aliases, :optional).each_with_object({}) do |(name, aliases, optional), mapping|
          [ name, *aliases ].each do |value|
            mapping[value] = { name:, optional: }
          end
        end
      end
    end
  end

  private

  def clear_cache
    Rails.cache.delete(CATALOG_NAMES_CACHE_KEY)
    Rails.cache.delete(CATALOG_METADATA_CACHE_KEY)
    Rails.cache.delete(FILTERABLE_LOOKUP_CACHE_KEY)
  end

  def aliases_must_be_valid
    if aliases.is_a?(Array)
      errors.add(:aliases, "must have at least one alias") if aliases.empty?
    else
      errors.add(:aliases, "must be an array")
    end
  end

  def aliases_must_be_unique
    others = self.class.where.not(id:)
    # pg array syntax for jsonb_exists_any
    if aliases.is_a?(Array) && aliases.any?
      if others.where("jsonb_exists_any(aliases, ARRAY[?]::text[])", aliases).exists?
        errors.add(:aliases, "must be unique across ingredients")
      end

      if others.where(name: aliases).exists?
        errors.add(:aliases, "must not match another ingredient name")
      end
    end

    if name.present? && others.where("jsonb_exists(aliases, ?)", name).exists?
      errors.add(:name, "must not match another ingredient alias")
    end
  end
end
